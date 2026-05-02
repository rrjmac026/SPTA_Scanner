import 'package:sqflite/sqflite.dart' as sqflite;
import '../models/models.dart';
import '../models/audit_log.dart';
import 'database_service.dart';
import 'settings_repository.dart';
import 'student_repository.dart';
import 'payment_repository.dart';
import 'audit_log_repository.dart';
import 'sync_repository.dart';

/// Facade for database operations. Coordinates multiple repositories
/// to provide a clean, unified API for database access.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  final DatabaseService _databaseService = DatabaseService();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final StudentRepository _studentRepository = StudentRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  final AuditLogRepository _auditLogRepository = AuditLogRepository();
  final SyncRepository _syncRepository = SyncRepository();

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // ─── Settings ──────────────────────────────────────────────────────────────

  Future<double> getTotalFee() => _settingsRepository.getTotalFee();

  Future<void> setTotalFee(double fee) => _settingsRepository.setTotalFee(fee);

  Future<String> generateTransactionNumber() =>
      _settingsRepository.generateTransactionNumber();

  Future<String> generateTempLrn() => _settingsRepository.generateTempLrn();

  // ─── Students ──────────────────────────────────────────────────────────────

  Future<int?> insertStudent(
    Student student, {
    String processedByUid = '',
    String processedByName = '',
  }) =>
      _studentRepository.insertStudent(student,
          processedByUid: processedByUid, processedByName: processedByName);

  Future<Student?> getStudentByLrn(String lrn) =>
      _studentRepository.getStudentByLrn(lrn);

  Future<bool> studentExists(String lrn) =>
      _studentRepository.studentExists(lrn);

  Future<List<Student>> getAllStudents() => _studentRepository.getAllStudents();

  Future<List<StudentPaymentInfo>> getUnlinkedTempStudents() =>
      _studentRepository.getUnlinkedTempStudents();

  Future<List<StudentPaymentInfo>> findTempCandidates(String scannedName) =>
      _studentRepository.findTempCandidates(scannedName);

  Future<bool> linkTempToLrn({
    required int tempStudentId,
    required String realLrn,
    required String realName,
    required String grade,
  }) =>
      _studentRepository.linkTempToLrn(
        tempStudentId: tempStudentId,
        realLrn: realLrn,
        realName: realName,
        grade: grade,
      );

  Future<bool> assignLrnToTemp({
    required int tempStudentId,
    required String realLrn,
  }) =>
      _studentRepository.assignLrnToTemp(
        tempStudentId: tempStudentId,
        realLrn: realLrn,
      );

  Future<int> getTotalStudentCount() =>
      _studentRepository.getTotalStudentCount();

  Future<Map<String, int>> getCountByGrade() =>
      _studentRepository.getCountByGrade();

  // ─── Payments ──────────────────────────────────────────────────────────────

  Future<Payment> addPayment(Payment payment) =>
      _paymentRepository.addPayment(payment);

  Future<void> markPaymentSynced(int paymentId) =>
      _paymentRepository.markPaymentSynced(paymentId);

  Future<List<Payment>> getPaymentsForStudent(int studentId) =>
      _paymentRepository.getPaymentsForStudent(studentId);

  Future<List<Payment>> getPendingPayments() =>
      _paymentRepository.getPendingPayments();

  Future<int> getPendingSyncCount() =>
      _paymentRepository.getPendingSyncCount();

  Future<List<Payment>> getPaymentsByProcessor(String uid) =>
      _paymentRepository.getPaymentsByProcessor(uid);

  Future<double> getAmountPaidForStudent(int studentId) =>
      _paymentRepository.getAmountPaidForStudent(studentId);

  Future<double> getTotalCollected() => _paymentRepository.getTotalCollected();

  Future<double> getTotalCollectedByProcessor(String uid) =>
      _paymentRepository.getTotalCollectedByProcessor(uid);

  Future<int?> editPaymentAmount({
    required int paymentId,
    required double oldAmount,
    required double newAmount,
    required String reason,
    required String processedByUid,
    required String processedByName,
    required String now,
  }) =>
      _paymentRepository.editPaymentAmount(
        paymentId: paymentId,
        oldAmount: oldAmount,
        newAmount: newAmount,
        reason: reason,
        processedByUid: processedByUid,
        processedByName: processedByName,
        now: now,
      );

  // ─── Audit Logs ────────────────────────────────────────────────────────────

  Future<List<AuditLog>> getAllAuditLogs() =>
      _auditLogRepository.getAllAuditLogs();

  Future<List<AuditLog>> getAuditLogsByUser(String uid) =>
      _auditLogRepository.getAuditLogsByUser(uid);

  Future<List<AuditLog>> getUnsyncedAuditLogs() =>
      _auditLogRepository.getUnsyncedAuditLogs();

  Future<void> markAuditLogSynced(int id) =>
      _auditLogRepository.markAuditLogSynced(id);

  // ─── Sync & Merge Operations ───────────────────────────────────────────────

  Future<StudentPaymentInfo?> getStudentPaymentInfo(String lrn) async {
    final student = await getStudentByLrn(lrn);
    if (student == null) return null;
    final totalFee = await getTotalFee();
    final payments = await getMergedPaymentsForStudent(student.id!);
    final amountPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    return StudentPaymentInfo(
        student: student,
        totalFee: totalFee,
        amountPaid: amountPaid,
        payments: payments);
  }

  Future<List<Payment>> getMergedPaymentsForStudent(int studentId) =>
      _syncRepository.getMergedPaymentsForStudent(studentId);

  // ─── Aggregates ────────────────────────────────────────────────────────────

  Future<List<StudentPaymentInfo>> getAllStudentPaymentInfos() async {
    final students = await getAllStudents();
    final totalFee = await getTotalFee();
    final List<StudentPaymentInfo> result = [];
    for (final s in students) {
      final payments = await getPaymentsForStudent(s.id!);
      final amountPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
      result.add(StudentPaymentInfo(
          student: s,
          totalFee: totalFee,
          amountPaid: amountPaid,
          payments: payments));
    }
    return result;
  }

  Future<List<StudentPaymentInfo>> getStudentPaymentInfosByProcessor(
      String uid) async {
    final totalFee = await getTotalFee();
    final paymentsForProcessor = await getPaymentsByProcessor(uid);

    // Group payments by student_id
    final Map<int, List<Payment>> paymentsByStudent = {};
    for (final p in paymentsForProcessor) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }

    final List<StudentPaymentInfo> result = [];
    for (final studentId in paymentsByStudent.keys) {
      final student = await _getStudentById(studentId);
      if (student != null) {
        final payments = paymentsByStudent[studentId]!;
        final amountPaid = payments.fold<double>(0, (s, p) => s + p.amount);
        result.add(StudentPaymentInfo(
            student: student,
            totalFee: totalFee,
            amountPaid: amountPaid,
            payments: payments));
      }
    }
    return result;
  }

  /// Helper to fetch a student by ID (not exposed in original API).
  Future<Student?> _getStudentById(int id) async {
    final db = await _databaseService.database;
    final rows = await db.query('students', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Student.fromMap(rows.first);
  }

  /// Upserts a student record received from Firestore into local SQLite.
  /// Matches by LRN (the Firestore doc ID). Creates or updates as needed.
  Future<void> upsertStudentFromFirestore(Map<String, dynamic> data) async {
    final db = await _databaseService.database;
    final lrn = data['lrn'] as String?;
    if (lrn == null || lrn.isEmpty) return;

    final existing = await db.query(
      'students',
      where: 'lrn = ?',
      whereArgs: [lrn],
      limit: 1,
    );

    final row = <String, dynamic>{
      'name': data['name'] ?? '',
      'lrn': lrn,
      'grade': data['grade'] ?? '',
      'created_at': data['createdAt'] ?? '',
      'is_temp': (data['isTemp'] == true) ? 1 : 0,
    };

    if (existing.isEmpty) {
      await db.insert('students', row,
          conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
    } else {
      await db.update('students', row,
          where: 'lrn = ?', whereArgs: [lrn]);
    }
  }

  /// Upserts a transaction (payment) received from Firestore into local SQLite.
  /// Matches by transaction_number. Skips if student not found locally.
  Future<void> upsertTransactionFromFirestore(Map<String, dynamic> data) async {
    final db = await _databaseService.database;
    final txn = data['transactionNumber'] as String?;
    if (txn == null || txn.isEmpty) return;

    // Resolve local student ID from LRN
    final lrn = data['lrn'] as String?;
    int? studentId = data['studentId'] as int?;

    if (studentId == null && lrn != null) {
      final rows = await db.query(
        'students',
        columns: ['id'],
        where: 'lrn = ?',
        whereArgs: [lrn],
        limit: 1,
      );
      if (rows.isEmpty) return; // Student not synced yet — skip
      studentId = rows.first['id'] as int;
    }
    if (studentId == null) return;

    final existing = await db.query(
      'payments',
      where: 'transaction_number = ?',
      whereArgs: [txn],
      limit: 1,
    );

    final row = <String, dynamic>{
      'student_id': studentId,
      'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
      'note': data['note'] ?? '',
      'created_at': data['createdAt'] ?? '',
      'transaction_number': txn,
      'processed_by_uid': data['processedByUid'] ?? '',
      'processed_by_name': data['processedByName'] ?? '',
      'synced': 1,
    };

    if (existing.isEmpty) {
      await db.insert('payments', row,
          conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
    } else {
      await db.update('payments', row,
          where: 'transaction_number = ?', whereArgs: [txn]);
    }
  }
}