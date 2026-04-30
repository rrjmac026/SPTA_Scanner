import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../helpers/database_helper.dart';

/// Syncs local SQLite data to Firestore.
///
/// Offline-first design:
///   1. Every write goes to SQLite first — works with zero network.
///   2. A `pending_sync` queue tracks payments that haven't been pushed yet.
///   3. On connectivity restore (or explicit [syncAll] call), the queue is
///      flushed to Firestore, and each successfully-written payment is marked
///      synced in SQLite.
///   4. [fetchPaymentsForStudent] lets any device pull the full authoritative
///      history from Firestore so offline payments by other teachers are
///      visible before this device has received them via the queue flush.
class FirestoreSyncService {
  static final FirestoreSyncService _instance =
      FirestoreSyncService._internal();
  factory FirestoreSyncService() => _instance;
  FirestoreSyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isFlushing = false;

  /// Call once from main() to start listening for connectivity changes.
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
      // Firestore SDK queues automatically when offline (persistence enabled).
    }
  }

  // ── Payments ─────────────────────────────────────────────────────────────

  /// Pushes [payment] to Firestore. If successful, calls [onSynced] so the
  /// caller can update the local `synced` flag. If offline, Firestore SDK
  /// queues it; [onSynced] is NOT called until the SDK confirms the write.
  Future<void> upsertPayment(
    Payment payment, {
    Future<void> Function()? onSynced,
  }) async {
    if (payment.id == null) return;
    try {
      await _db
          .collection('payments')
          .doc(payment.id.toString())
          .set(_paymentToMap(payment), SetOptions(merge: true));
      // Write succeeded — mark synced locally
      if (onSynced != null) await onSynced();
    } catch (_) {
      // Offline write: SDK queues it. We do NOT call onSynced here because
      // we can't confirm the server received it. The pending_sync queue
      // ensures _flushPending() will retry when connectivity returns.
    }
  }

  // ── Fetch from Firestore (read path) ─────────────────────────────────────

  /// Returns all payments for a student from Firestore.
  /// Throws if offline or Firestore is unavailable — caller should catch.
  Future<List<Payment>> fetchPaymentsForStudent(int studentId) async {
    final snapshot = await _db
        .collection('payments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: false)
        .get(const GetOptions(source: Source.serverAndCache));

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Payment(
        id: data['id'] as int?,
        studentId: data['studentId'] as int,
        amount: (data['amount'] as num).toDouble(),
        note: data['note'] as String? ?? '',
        createdAt: data['createdAt'] as String? ?? '',
        transactionNumber: data['transactionNumber'] as String? ?? '',
        processedByUid: data['processedByUid'] as String? ?? '',
        processedByName: data['processedByName'] as String? ?? '',
        synced: true,
      );
    }).toList();
  }

  // ── Flush pending queue ───────────────────────────────────────────────────

  /// Pushes all unsynced local payments to Firestore.
  /// Guards against concurrent runs with [_isFlushing].
  Future<void> _flushPending() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      final dbHelper = DatabaseHelper();

      // Push any unsynced payments
      final pending = await dbHelper.getPendingPayments();
      for (final payment in pending) {
        await upsertPayment(payment, onSynced: () async {
          if (payment.id != null) {
            await dbHelper.markPaymentSynced(payment.id!);
          }
        });
      }

      // Also push all students (lightweight, idempotent)
      final students = await dbHelper.getAllStudents();
      for (final s in students) {
        await upsertStudent(s);
      }
    } catch (_) {
      // Will retry next time connectivity is restored
    } finally {
      _isFlushing = false;
    }
  }

  /// Public entry point — call after login or to force a sync.
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