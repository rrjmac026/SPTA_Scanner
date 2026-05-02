import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../services/firestore_sync_service.dart';
import '../models/audit_log.dart';
import 'database_service.dart';
import 'settings_repository.dart';

/// Repository for student-related operations.
class StudentRepository {
  final DatabaseService _databaseService = DatabaseService();
  final SettingsRepository _settingsRepository = SettingsRepository();

  Future<Database> get _database => _databaseService.database;

  Future<int?> insertStudent(
    Student student, {
    String processedByUid = '',
    String processedByName = '',
  }) async {
    final db = await _database;
    final existing =
        await db.query('students', where: 'lrn = ?', whereArgs: [student.lrn]);
    if (existing.isNotEmpty) return null;

    late final int id;
    late final AuditLog auditLog;

    await db.transaction((txn) async {
      id = await txn.insert('students', student.toMap());

      auditLog = AuditLog(
        action: AuditAction.studentRegistered,
        targetType: 'student',
        targetId: id,
        newValue: '${student.name} (${student.lrn})',
        processedByUid: processedByUid,
        processedByName: processedByName,
        createdAt: student.createdAt,
        synced: false,
      );
      await txn.insert('audit_logs', auditLog.toMap());
    });

    final inserted = Student(
      id: id,
      name: student.name,
      lrn: student.lrn,
      grade: student.grade,
      createdAt: student.createdAt,
      isTemp: student.isTemp,
    );

    final syncService = FirestoreSyncService();
    syncService.upsertStudent(inserted);
    syncService.upsertAuditLog(AuditLog(
      id: id,
      action: auditLog.action,
      targetType: auditLog.targetType,
      targetId: auditLog.targetId,
      newValue: auditLog.newValue,
      processedByUid: auditLog.processedByUid,
      processedByName: auditLog.processedByName,
      createdAt: auditLog.createdAt,
      synced: false,
    ));

    return id;
  }

  Future<Student?> getStudentByLrn(String lrn) async {
    final db = await _database;
    final rows =
        await db.query('students', where: 'lrn = ?', whereArgs: [lrn]);
    if (rows.isEmpty) return null;
    return Student.fromMap(rows.first);
  }

  Future<bool> studentExists(String lrn) async {
    final db = await _database;
    final result =
        await db.query('students', where: 'lrn = ?', whereArgs: [lrn]);
    return result.isNotEmpty;
  }

  Future<List<Student>> getAllStudents() async {
    final db = await _database;
    final maps = await db.query('students', orderBy: 'created_at DESC');
    return maps.map(Student.fromMap).toList();
  }

  Future<List<StudentPaymentInfo>> getUnlinkedTempStudents() async {
    final db = await _database;
    final rows = await db.query('students',
        where: 'is_temp = 1', orderBy: 'created_at DESC');
    final totalFee = await _settingsRepository.getTotalFee();
    final List<StudentPaymentInfo> result = [];
    for (final row in rows) {
      final s = Student.fromMap(row);
      final payments = await _getPaymentsForStudent(s.id!);
      final amountPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
      result.add(StudentPaymentInfo(
          student: s,
          totalFee: totalFee,
          amountPaid: amountPaid,
          payments: payments));
    }
    return result;
  }

  Future<List<StudentPaymentInfo>> findTempCandidates(
      String scannedName) async {
    final temps = await getUnlinkedTempStudents();
    if (temps.isEmpty) return [];

    final needle = scannedName.toLowerCase().trim();
    List<MapEntry<StudentPaymentInfo, int>> scored = [];
    for (final info in temps) {
      final haystack = info.student.name.toLowerCase();
      final words = needle.split(RegExp(r'\s+'));
      int score = 0;
      for (final w in words) {
        if (w.isNotEmpty && haystack.contains(w)) score++;
      }
      if (haystack == needle) score += 100;
      if (score > 0) scored.add(MapEntry(info, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  Future<bool> linkTempToLrn({
    required int tempStudentId,
    required String realLrn,
    required String realName,
    required String grade,
    String processedByUid = '',
    String processedByName = '',
  }) async {
    final db = await _database;
    final existing =
        await db.query('students', where: 'lrn = ?', whereArgs: [realLrn]);

    int realStudentId;
    if (existing.isNotEmpty) {
      realStudentId = existing.first['id'] as int;
    } else {
      final now = DateTime.now().toIso8601String();
      realStudentId = await db.insert('students', {
        'name': realName,
        'lrn': realLrn,
        'grade': grade,
        'created_at': now,
        'is_temp': 0,
      });
    }

    await db.update(
      'payments',
      {'student_id': realStudentId},
      where: 'student_id = ?',
      whereArgs: [tempStudentId],
    );
    await db.delete('students', where: 'id = ?', whereArgs: [tempStudentId]);

    // Log the LRN link action
    final now = DateTime.now().toIso8601String();
    final auditLog = AuditLog(
      action: AuditAction.lrnLinked,
      targetType: 'student',
      targetId: realStudentId,
      oldValue: 'TEMP-$tempStudentId',
      newValue: realLrn,
      processedByUid: processedByUid,
      processedByName: processedByName,
      createdAt: now,
      synced: false,
    );
    await db.insert('audit_logs', auditLog.toMap());
    FirestoreSyncService().upsertAuditLog(auditLog);

    return true;
  }

  Future<bool> assignLrnToTemp({
    required int tempStudentId,
    required String realLrn,
    String processedByUid = '',
    String processedByName = '',
  }) async {
    final db = await _database;
    final conflict =
        await db.query('students', where: 'lrn = ?', whereArgs: [realLrn]);
    if (conflict.isNotEmpty) return false;
    await db.update(
      'students',
      {'lrn': realLrn, 'is_temp': 0},
      where: 'id = ?',
      whereArgs: [tempStudentId],
    );

    // Log the LRN assign action
    final now = DateTime.now().toIso8601String();
    final auditLog = AuditLog(
      action: AuditAction.lrnAssigned,
      targetType: 'student',
      targetId: tempStudentId,
      newValue: realLrn,
      processedByUid: processedByUid,
      processedByName: processedByName,
      createdAt: now,
      synced: false,
    );
    await db.insert('audit_logs', auditLog.toMap());
    FirestoreSyncService().upsertAuditLog(auditLog);

    return true;
  }

  Future<int> getTotalStudentCount() async {
    final db = await _database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM students');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getCountByGrade() async {
    final db = await _database;
    final result = await db.rawQuery(
        'SELECT grade, COUNT(*) as count FROM students GROUP BY grade ORDER BY grade');
    return {
      for (var row in result)
        row['grade'] as String: row['count'] as int
    };
  }

  /// Helper method to get payments for a student (used internally).
  Future<List<Payment>> _getPaymentsForStudent(int studentId) async {
    final db = await _database;
    final maps = await db.query(
      'payments',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at ASC',
    );
    return maps.map(Payment.fromMap).toList();
  }
}