import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../models/audit_log.dart';
import '../helpers/database_helper.dart';

class FirestoreSyncService {
  static final FirestoreSyncService _instance = FirestoreSyncService._internal();
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

  Future<void> upsertStudent(Student student) async {
    if (student.id == null) return;
    try {
      await _db
          .collection('students')
          .doc(student.id.toString())
          .set(_studentToMap(student), SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> upsertPayment(Payment payment, {Future<void> Function()? onSynced}) async {
    if (payment.id == null) return;
    try {
      await _db
          .collection('payments')
          .doc(payment.id.toString())
          .set(_paymentToMap(payment), SetOptions(merge: true));
      if (onSynced != null) await onSynced();
    } catch (_) {}
  }

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

  Future<void> syncPendingAuditLogs() async {
    final logs = await DatabaseHelper().getUnsyncedAuditLogs();
    for (final log in logs) {
      try {
        await _db
            .collection('audit_logs')
            .doc('${log.processedByUid}_${log.createdAt}_${log.targetId}')
            .set(log.toFirestore());
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
          if (payment.id != null) await dbHelper.markPaymentSynced(payment.id!);
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