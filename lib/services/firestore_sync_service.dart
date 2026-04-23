import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../helpers/database_helper.dart';

/// Syncs local SQLite data to Firestore.
/// - Writes happen locally first (always works offline).
/// - Sync to Firestore happens immediately if online,
///   or is queued and flushed when connectivity returns.
class FirestoreSyncService {
  static final FirestoreSyncService _instance =
      FirestoreSyncService._internal();
  factory FirestoreSyncService() => _instance;
  FirestoreSyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Call once from main() to start listening for connectivity.
  void init() {
    Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet) _flushPending();
    });
  }

  // ── Students ─────────────────────────────────────────────────────────────

  Future<void> upsertStudent(Student student) async {
    if (student.id == null) return;
    try {
      await _db
          .collection('students')
          .doc(student.id.toString())
          .set(_studentToMap(student), SetOptions(merge: true));
    } catch (_) {
      // Offline — Firestore SDK queues automatically when offline
      // because persistence is enabled by default on mobile.
    }
  }

  // ── Payments ─────────────────────────────────────────────────────────────

  Future<void> upsertPayment(Payment payment) async {
    if (payment.id == null) return;
    try {
      await _db
          .collection('payments')
          .doc(payment.id.toString())
          .set(_paymentToMap(payment), SetOptions(merge: true));
    } catch (_) {
      // Same — SDK handles offline queueing automatically
    }
  }

  // ── Full sync (push all local → Firestore) ───────────────────────────────
  // Call this after login or when connectivity is restored.

  Future<void> _flushPending() async {
    try {
      final dbHelper = DatabaseHelper();
      final students = await dbHelper.getAllStudents();
      for (final s in students) {
        await upsertStudent(s);
      }

      final infos = await dbHelper.getAllStudentPaymentInfos();
      for (final info in infos) {
        for (final p in info.payments) {
          await upsertPayment(p);
        }
      }
    } catch (_) {}
  }

  Future<void> syncAll() => _flushPending();

  // ── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _studentToMap(Student s) => {
        'id': s.id,
        'name': s.name,
        'lrn': s.lrn,
        'grade': s.grade,
        'createdAt': s.createdAt,
        'isTemp': s.isTemp,
        'syncedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _paymentToMap(Payment p) => {
        'id': p.id,
        'studentId': p.studentId,
        'amount': p.amount,
        'note': p.note,
        'createdAt': p.createdAt,
        'transactionNumber': p.transactionNumber,
        'processedByUid': p.processedByUid,
        'processedByName': p.processedByName,
        'syncedAt': FieldValue.serverTimestamp(),
      };
}