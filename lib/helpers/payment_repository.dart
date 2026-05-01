import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../services/firestore_sync_service.dart';
import '../models/audit_log.dart';
import 'database_service.dart';
import 'settings_repository.dart';

/// Repository for payment-related operations.
class PaymentRepository {
  final DatabaseService _databaseService = DatabaseService();
  final SettingsRepository _settingsRepository = SettingsRepository();

  Future<Database> get _database => _databaseService.database;

  Future<Payment> addPayment(Payment payment) async {
    final db = await _database;
    final txn = payment.transactionNumber.isNotEmpty
        ? payment.transactionNumber
        : await _databaseService.nextTransactionNumber(db);
    final withTxn = Payment(
      studentId: payment.studentId,
      amount: payment.amount,
      note: payment.note,
      createdAt: payment.createdAt,
      transactionNumber: txn,
      processedByUid: payment.processedByUid,
      processedByName: payment.processedByName,
      synced: false,
    );

    final map = withTxn.toMap();
    map['synced'] = 0;

    late final int id;
    late final Payment saved;

    // Write payment + audit log atomically
    await db.transaction((txnDb) async {
      id = await txnDb.insert('payments', map);

      // Queue for Firestore sync
      await txnDb.insert(
        'pending_sync',
        {'payment_id': id, 'synced': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // ── Audit log entry ──────────────────────────────────────────────────
      final log = AuditLog(
        action: AuditAction.paymentAdded,
        targetType: 'payment',
        targetId: id,
        oldValue: null,
        newValue: '₱${withTxn.amount.toStringAsFixed(2)}',
        reason: withTxn.note.isNotEmpty ? withTxn.note : null,
        processedByUid: withTxn.processedByUid,
        processedByName: withTxn.processedByName,
        createdAt: withTxn.createdAt,
        synced: false,
      );
      await txnDb.insert('audit_logs', log.toMap());
    });

    saved = Payment(
      id: id,
      studentId: withTxn.studentId,
      amount: withTxn.amount,
      note: withTxn.note,
      createdAt: withTxn.createdAt,
      transactionNumber: withTxn.transactionNumber,
      processedByUid: withTxn.processedByUid,
      processedByName: withTxn.processedByName,
      synced: false,
    );

    // Attempt immediate Firestore sync
    FirestoreSyncService().upsertPayment(saved, onSynced: () async {
      await markPaymentSynced(id);
    });
    FirestoreSyncService().syncPendingAuditLogs();

    return saved;
  }

  /// Called by FirestoreSyncService after a successful Firestore write.
  Future<void> markPaymentSynced(int paymentId) async {
    final db = await _database;
    await db.update(
      'payments',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [paymentId],
    );
    await db.update(
      'pending_sync',
      {'synced': 1},
      where: 'payment_id = ?',
      whereArgs: [paymentId],
    );
  }

  Future<List<Payment>> getPaymentsForStudent(int studentId) async {
    final db = await _database;
    final maps = await db.query(
      'payments',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at ASC',
    );
    return maps.map(Payment.fromMap).toList();
  }

  /// Returns payments with [synced = 0] that haven't been pushed to Firestore.
  Future<List<Payment>> getPendingPayments() async {
    final db = await _database;
    final maps = await db.rawQuery('''
      SELECT p.* FROM payments p
      INNER JOIN pending_sync ps ON ps.payment_id = p.id
      WHERE ps.synced = 0
    ''');
    return maps.map(Payment.fromMap).toList();
  }

  /// Returns count of payments waiting to sync (for UI badge).
  Future<int> getPendingSyncCount() async {
    final db = await _database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pending_sync WHERE synced = 0');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<Payment>> getPaymentsByProcessor(String uid) async {
    final db = await _database;
    final maps = await db.query(
      'payments',
      where: 'processed_by_uid = ?',
      whereArgs: [uid],
      orderBy: 'created_at DESC',
    );
    return maps.map(Payment.fromMap).toList();
  }

  Future<double> getAmountPaidForStudent(int studentId) async {
    final db = await _database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payments WHERE student_id = ?',
        [studentId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalCollected() async {
    final db = await _database;
    final result =
        await db.rawQuery('SELECT SUM(amount) as total FROM payments');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalCollectedByProcessor(String uid) async {
    final db = await _database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payments WHERE processed_by_uid = ?',
        [uid]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Inserts a payment fetched from Firestore into local SQLite (marked as synced).
  Future<void> insertRemotePaymentLocally(Payment payment) async {
    final db = await _database;
    // Avoid duplicates by transaction_number
    final existing = await db.query('payments',
        where: 'transaction_number = ?',
        whereArgs: [payment.transactionNumber]);
    if (existing.isNotEmpty) return;

    final map = payment.toMap();
    map['synced'] = 1; // already synced — don't re-queue
    await db.insert('payments', map,
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Edit a payment's amount (keeps old record, writes audit log atomically).
  /// Returns the audit log id on success, or null on failure.
  Future<int?> editPaymentAmount({
    required int paymentId,
    required double oldAmount,
    required double newAmount,
    required String reason,
    required String processedByUid,
    required String processedByName,
    required String now,
  }) async {
    final db = await _database;
    return await db.transaction((txn) async {
      // 1. Update the payment record
      final updated = await txn.update(
        'payments',
        {'amount': newAmount},
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      if (updated == 0) return null;

      // 2. Write the immutable audit entry
      final log = AuditLog(
        action: AuditAction.paymentEdited,
        targetType: 'payment',
        targetId: paymentId,
        oldValue: '₱${oldAmount.toStringAsFixed(2)}',
        newValue: '₱${newAmount.toStringAsFixed(2)}',
        reason: reason.trim().isEmpty ? null : reason.trim(),
        processedByUid: processedByUid,
        processedByName: processedByName,
        createdAt: now,
        synced: false,
      );
      final logId = await txn.insert('audit_logs', log.toMap());
      return logId;
    });
  }
}
