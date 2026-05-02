import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/models.dart';
import '../helpers/database_helper.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _db = DatabaseHelper();

  // ── Get all users (admin only) ───────────────────────────────────────────

  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .orderBy('createdAt', descending: false)
        .get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data()))
        .toList();
  }

  // ── Update user role (admin only) ────────────────────────────────────────

  Future<void> updateUserRole(String uid, UserRole role) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role.name,
    });
  }

  // ── Get single user ──────────────────────────────────────────────────────

  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }

  // ── Stream users (real-time updates) ────────────────────────────────────

  Stream<List<AppUser>> usersStream() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromMap(doc.data()))
            .toList());
  }

  // ── Delete user (admin only) ─────────────────────────────────────────────

  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // ────────────────────────────────────────────────────────────────────────
  // NEW: Sync helpers for stale-data fixes
  // ────────────────────────────────────────────────────────────────────────

  /// Pulls the latest student + their transactions from Firestore into the
  /// local SQLite database, then returns the merged [StudentPaymentInfo].
  ///
  /// Used by [ResultScreen] and [StudentDetailScreen] so scans always show
  /// fresh data even when another device recorded a payment.
  ///
  /// Silently falls through to whatever is already in SQLite if offline.
  Future<StudentPaymentInfo?> syncAndGetStudentPaymentInfo(String lrn) async {
    try {
      // 1. Pull student doc
      final studentDoc =
          await _firestore.collection('students').doc(lrn).get();
      if (studentDoc.exists && studentDoc.data() != null) {
        await _db.upsertStudentFromFirestore(studentDoc.data()!);
      }

      // 2. Pull all transactions for this student
      final txSnap = await _firestore
          .collection('transactions')
          .where('lrn', isEqualTo: lrn)
          .get();
      for (final doc in txSnap.docs) {
        await _db.upsertTransactionFromFirestore(doc.data());
      }
    } catch (_) {
      // Offline or Firestore error — fall through to local data below.
    }

    // 3. Always return from SQLite (the single source of truth for the UI)
    return _db.getStudentPaymentInfo(lrn);
  }

  /// Returns a live Firestore stream of [StudentPaymentInfo] for a single
  /// student. Used by [StudentDetailScreen] so the payment history refreshes
  /// in real-time without a manual pull.
  ///
  /// The stream re-emits whenever either the student doc or any of their
  /// transaction docs change in Firestore.
  Stream<StudentPaymentInfo?> studentPaymentInfoStream(String lrn) {
    // Stream the student document; on each change also re-fetch transactions.
    return _firestore
        .collection('students')
        .doc(lrn)
        .snapshots()
        .asyncMap((studentDoc) async {
      if (!studentDoc.exists || studentDoc.data() == null) return null;

      // Write the latest student data into SQLite so the rest of the app
      // (exports, home-screen stats, etc.) stays consistent.
      try {
        await _db.upsertStudentFromFirestore(studentDoc.data()!);

        final txSnap = await _firestore
            .collection('transactions')
            .where('lrn', isEqualTo: lrn)
            .get();
        for (final doc in txSnap.docs) {
          await _db.upsertTransactionFromFirestore(doc.data());
        }
      } catch (_) {
        // Ignore write errors — the UI will still show the last good data.
      }

      return _db.getStudentPaymentInfo(lrn);
    });
  }

  /// Returns a live Firestore stream of all [StudentPaymentInfo] records that
  /// were processed by [processorUid]. Used by [TeacherRecordsScreen].
  ///
  /// Re-emits whenever any transaction for this teacher changes in Firestore.
  Stream<List<StudentPaymentInfo>> teacherRecordsStream(String processorUid) {
    return _firestore
        .collection('transactions')
        .where('processedByUid', isEqualTo: processorUid)
        .snapshots()
        .asyncMap((txSnap) async {
      // Collect unique LRNs touched by this teacher.
      final lrns = txSnap.docs
          .map((d) => d.data()['lrn'] as String?)
          .whereType<String>()
          .toSet();

      // For each unique LRN, sync the student + all their transactions into
      // SQLite, then read the merged result back.
      final infos = <StudentPaymentInfo>[];
      for (final lrn in lrns) {
        try {
          final studentDoc =
              await _firestore.collection('students').doc(lrn).get();
          if (studentDoc.exists && studentDoc.data() != null) {
            await _db.upsertStudentFromFirestore(studentDoc.data()!);
          }
          // Upsert every transaction for this LRN (not just this teacher's)
          // so the "amount paid" total is always correct.
          final allTx = await _firestore
              .collection('transactions')
              .where('lrn', isEqualTo: lrn)
              .get();
          for (final doc in allTx.docs) {
            await _db.upsertTransactionFromFirestore(doc.data());
          }
        } catch (_) {
          // Stay offline-safe; use whatever SQLite already has.
        }
        final info = await _db.getStudentPaymentInfo(lrn);
        if (info != null) infos.add(info);
      }
      return infos;
    });
  }
}