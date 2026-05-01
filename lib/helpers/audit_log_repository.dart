import 'package:sqflite/sqflite.dart';
import '../models/audit_log.dart';
import 'database_service.dart';

/// Repository for audit log operations.
class AuditLogRepository {
  final DatabaseService _databaseService = DatabaseService();

  Future<Database> get _database => _databaseService.database;

  Future<List<AuditLog>> getAllAuditLogs() async {
    final db = await _database;
    final rows = await db.query(
      'audit_logs',
      orderBy: 'created_at DESC',
    );
    return rows.map(AuditLog.fromMap).toList();
  }

  Future<List<AuditLog>> getAuditLogsByUser(String uid) async {
    final db = await _database;
    final rows = await db.query(
      'audit_logs',
      where: 'processed_by_uid = ?',
      whereArgs: [uid],
      orderBy: 'created_at DESC',
    );
    return rows.map(AuditLog.fromMap).toList();
  }

  Future<List<AuditLog>> getUnsyncedAuditLogs() async {
    final db = await _database;
    final rows = await db.query(
      'audit_logs',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(AuditLog.fromMap).toList();
  }

  Future<void> markAuditLogSynced(int id) async {
    final db = await _database;
    await db.update(
      'audit_logs',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
