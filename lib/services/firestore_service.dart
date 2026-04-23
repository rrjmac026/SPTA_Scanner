import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/models.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> upsertStudentSummary(StudentPaymentInfo info) async {
    final student = info.student;
    final latestPayment = info.payments.isNotEmpty ? info.payments.last : null;

    await _firestore.collection('students').doc(student.lrn).set({
      'name': student.name,
      'lrn': student.lrn,
      'grade': student.grade,
      'createdAt': student.createdAt,
      'isTemp': student.isTempRecord,
      'localStudentId': student.id,
      'totalFee': info.totalFee,
      'amountPaid': info.amountPaid,
      'remainingBalance': info.remainingBalance,
      'paymentStatus': info.paymentStatus,
      'paymentCount': info.payments.length,
      'lastTransactionNumber': latestPayment?.transactionNumber ?? '',
      'lastPaymentAt': latestPayment?.createdAt ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertPayment({
    required Student student,
    required Payment payment,
  }) async {
    final docId = payment.transactionNumber.isNotEmpty
        ? payment.transactionNumber
        : '${student.lrn}_${payment.createdAt}';

    await _firestore.collection('payments').doc(docId).set({
      'studentLrn': student.lrn,
      'studentName': student.name,
      'studentGrade': student.grade,
      'studentIsTemp': student.isTempRecord,
      'localStudentId': student.id,
      'localPaymentId': payment.id,
      'amount': payment.amount,
      'note': payment.note,
      'createdAt': payment.createdAt,
      'transactionNumber': payment.transactionNumber,
      'processedByUid': payment.processedByUid,
      'processedByName': payment.processedByName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> relinkStudentRecords({
    required String oldLrn,
    required StudentPaymentInfo newInfo,
  }) async {
    await upsertStudentSummary(newInfo);

    if (oldLrn != newInfo.student.lrn) {
      final paymentDocs = await _firestore
          .collection('payments')
          .where('studentLrn', isEqualTo: oldLrn)
          .get();

      for (final doc in paymentDocs.docs) {
        await doc.reference.set({
          'studentLrn': newInfo.student.lrn,
          'studentName': newInfo.student.name,
          'studentGrade': newInfo.student.grade,
          'studentIsTemp': newInfo.student.isTempRecord,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await _firestore.collection('students').doc(oldLrn).delete();
    }
  }
}
