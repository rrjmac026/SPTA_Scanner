import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../models/audit_log.dart';
import '../helpers/database_helper.dart';

class FirestoreSyncService {
  static final FirestoreSyncService _instance =
      FirestoreSyncService._internal();
  factory FirestoreSyncService() => _instance;
  FirestoreSyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isFlushing = false;

  void init() {
    Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet) syncAll();
    });
  }

  // ── Real-time stream: ALL payments across all devices ──────────────────────
  Stream<List<Payment>> paymentsStream() {
    return _db
        .collection('payments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
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
            }).toList());
  }

  // ── Real-time stream: payments for a specific student ─────────────────────
  Stream<List<Payment>> paymentsStreamForStudent(int studentId) {
    return _db
        .collection('payments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
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
            }).toList());
  }

  // ── Real-time stream: ALL audit logs across all devices ───────────────────
  Stream<List<AuditLog>> auditLogsStream() {
    return _db
        .collection('audit_logs')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return AuditLog(
                action: data['action'] as String? ?? '',
                targetType: data['target_type'] as String? ?? '',
                targetId: data['target_id'] as int?,
                oldValue: data['old_value'] as String?,
                newValue: data['new_value'] as String?,
                reason: data['reason'] as String?,
                processedByUid: data['processed_by_uid'] as String? ?? '',
                processedByName: data['processed_by_name'] as String? ?? '',
                createdAt: data['created_at'] as String? ?? '',
                synced: true,
              );
            }).toList());
  }

  // ── Real-time stream: audit logs for a specific user ─────────────────────
  Stream<List<AuditLog>> auditLogsStreamForUser(String uid) {
    return _db
        .collection('audit_logs')
        .where('processed_by_uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return AuditLog(
                action: data['action'] as String? ?? '',
                targetType: data['target_type'] as String? ?? '',
                targetId: data['target_id'] as int?,
                oldValue: data['old_value'] as String?,
                newValue: data['new_value'] as String?,
                reason: data['reason'] as String?,
                processedByUid: data['processed_by_uid'] as String? ?? '',
                processedByName: data['processed_by_name'] as String? ?? '',
                createdAt: data['created_at'] as String? ?? '',
                synced: true,
              );
            }).toList());
  }

  // ── Real-time stream: all students ────────────────────────────────────────
  Stream<List<Student>> studentsStream() {
    return _db
        .collection('students')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return Student(
                id: data['id'] as int?,
                name: data['name'] as String? ?? '',
                lrn: data['lrn'] as String? ?? '',
                grade: data['grade'] as String? ?? '',
                createdAt: data['createdAt'] as String? ?? '',
                isTemp: data['isTemp'] as bool? ?? false,
              );
            }).toList());
  }

  // ── One-time fetch: payments for student (used for fallback/merge) ─────────
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

  // ── Write operations ───────────────────────────────────────────────────────

  Future<void> upsertStudent(Student student) async {
    if (student.id == null) return;
    try {
      await _db
          .collection('students')
          .doc(student.id.toString())
          .set(_studentToMap(student), SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> upsertPayment(Payment payment,
      {Future<void> Function()? onSynced}) async {
    if (payment.id == null) return;
    try {
      await _db
          .collection('payments')
          .doc(payment.id.toString())
          .set(_paymentToMap(payment), SetOptions(merge: true));
      if (onSynced != null) await onSynced();
    } catch (_) {}
  }

  Future<void> upsertAuditLog(AuditLog log) async {
    try {
      final docId =
          '${log.processedByUid}_${log.createdAt}_${log.targetId}'
              .replaceAll(RegExp(r'[^\w_-]'), '_');
      await _db
          .collection('audit_logs')
          .doc(docId)
          .set(log.toFirestore(), SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> syncPendingAuditLogs() async {
    final logs = await DatabaseHelper().getUnsyncedAuditLogs();
    for (final log in logs) {
      try {
        await upsertAuditLog(log);
        if (log.id != null) await DatabaseHelper().markAuditLogSynced(log.id!);
      } catch (_) {}
    }
  }

  Future<void> syncAll() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final dbHelper = DatabaseHelper();
      final pending = await dbHelper.getPendingPayments();
      for (final payment in pending) {
        await upsertPayment(payment, onSynced: () async {
          if (payment.id != null) {
            await dbHelper.markPaymentSynced(payment.id!);
          }
        });
      }
      final students = await dbHelper.getAllStudents();
      for (final s in students) {
        await upsertStudent(s);
      }
      await syncPendingAuditLogs();
    } catch (_) {} finally {
      _isFlushing = false;
    }
  }

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