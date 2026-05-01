import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../services/firestore_sync_service.dart';
import '../models/audit_log.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'spta_payments.db');
    return await openDatabase(
      path,
      version: 8, // bumped from 6 → 7
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Students table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        lrn TEXT NOT NULL UNIQUE,
        grade TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        is_temp INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Payments table
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        transaction_number TEXT NOT NULL DEFAULT '',
        processed_by_uid TEXT NOT NULL DEFAULT '',
        processed_by_name TEXT NOT NULL DEFAULT '',
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (student_id) REFERENCES students(id)
      )
    ''');

    // Audit log table
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_id INTEGER,
        old_value TEXT,
        new_value TEXT,
        reason TEXT,
        processed_by_uid TEXT NOT NULL DEFAULT '',
        processed_by_name TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Pending sync queue — tracks payment IDs that haven't been pushed yet
    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_id INTEGER NOT NULL UNIQUE,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.insert('settings', {'key': 'total_fee', 'value': '750'});
    await db.insert('settings', {'key': 'txn_counter', 'value': '0'});
    await db.insert('settings', {'key': 'temp_counter', 'value': '0'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          transaction_number TEXT NOT NULL DEFAULT '',
          processed_by_uid TEXT NOT NULL DEFAULT '',
          processed_by_name TEXT NOT NULL DEFAULT '',
          synced INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (student_id) REFERENCES students(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      try {
        final oldStudents = await db.rawQuery(
            'SELECT id, amount, created_at FROM students WHERE amount IS NOT NULL AND amount > 0');
        for (final row in oldStudents) {
          final sid = row['id'] as int;
          final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
          if (amt > 0) {
            await db.insert('payments', {
              'student_id': sid,
              'amount': amt,
              'note': 'Migrated payment',
              'created_at': row['created_at'] as String,
              'transaction_number': '',
              'processed_by_uid': '',
              'processed_by_name': '',
              'synced': 0,
            });
          }
        }
      } catch (_) {}
      await db.insert('settings', {'key': 'total_fee', 'value': '750'},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('settings', {'key': 'txn_counter', 'value': '0'},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    if (oldVersion < 4) {
      try {
        await db.execute(
            'ALTER TABLE payments ADD COLUMN transaction_number TEXT NOT NULL DEFAULT \'\'');
      } catch (_) {}
      await db.insert('settings', {'key': 'txn_counter', 'value': '0'},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      final rows = await db.query('payments', orderBy: 'id ASC');
      for (final row in rows) {
        final id = row['id'] as int;
        final existing = row['transaction_number'] as String? ?? '';
        if (existing.isEmpty) {
          final txn = await _nextTransactionNumber(db);
          await db.update('payments', {'transaction_number': txn},
              where: 'id = ?', whereArgs: [id]);
        }
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute(
            'ALTER TABLE students ADD COLUMN is_temp INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      await db.insert('settings', {'key': 'temp_counter', 'value': '0'},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    if (oldVersion < 6) {
      try {
        await db.execute(
            'ALTER TABLE payments ADD COLUMN processed_by_uid TEXT NOT NULL DEFAULT \'\'');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE payments ADD COLUMN processed_by_name TEXT NOT NULL DEFAULT \'\'');
      } catch (_) {}
    }

    // v7: add synced column to payments + proper pending_sync table
    if (oldVersion < 7) {
      try {
        await db.execute(
            'ALTER TABLE payments ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}

      // Create pending_sync if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_sync (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payment_id INTEGER NOT NULL UNIQUE,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Mark all existing payments as unsynced so they get pushed on next flush
      try {
        await db.execute('UPDATE payments SET synced = 0');
      } catch (_) {}
    }

    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          target_type TEXT NOT NULL,
          target_id INTEGER,
          old_value TEXT,
          new_value TEXT,
          reason TEXT,
          processed_by_uid TEXT NOT NULL DEFAULT '',
          processed_by_name TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  // ─── Transaction number generator ─────────────────────────────────────────

  Future<String> _nextTransactionNumber(DatabaseExecutor db) async {
    final rows = await db
        .query('settings', where: 'key = ?', whereArgs: ['txn_counter']);
    final current =
        int.tryParse(rows.isEmpty ? '0' : rows.first['value'] as String) ?? 0;
    final next = current + 1;
    await db.insert('settings', {'key': 'txn_counter', 'value': next.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'TXN-$dateStr-${next.toString().padLeft(5, '0')}';
  }

  Future<String> generateTransactionNumber() async {
    final db = await database;
    return _nextTransactionNumber(db);
  }

  // ─── Temp LRN generator ────────────────────────────────────────────────────

  Future<String> _nextTempLrn(DatabaseExecutor db) async {
    final rows = await db
        .query('settings', where: 'key = ?', whereArgs: ['temp_counter']);
    final current =
        int.tryParse(rows.isEmpty ? '0' : rows.first['value'] as String) ?? 0;
    final next = current + 1;
    await db.insert('settings',
        {'key': 'temp_counter', 'value': next.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return 'TEMP-${next.toString().padLeft(6, '0')}';
  }

  Future<String> generateTempLrn() async {
    final db = await database;
    return _nextTempLrn(db);
  }

  // ─── Settings ──────────────────────────────────────────────────────────────

  Future<double> getTotalFee() async {
    final db = await database;
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: ['total_fee']);
    if (rows.isEmpty) return 750.0;
    return double.tryParse(rows.first['value'] as String) ?? 750.0;
  }

  Future<void> setTotalFee(double fee) async {
    final db = await database;
    await db.insert('settings', {'key': 'total_fee', 'value': fee.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── Students ──────────────────────────────────────────────────────────────

  Future<int?> insertStudent(Student student) async {
    final db = await database;
    final existing =
        await db.query('students', where: 'lrn = ?', whereArgs: [student.lrn]);
    if (existing.isNotEmpty) return null;
    final id = await db.insert('students', student.toMap());

    final inserted = Student(
      id: id,
      name: student.name,
      lrn: student.lrn,
      grade: student.grade,
      createdAt: student.createdAt,
      isTemp: student.isTemp,
    );
    FirestoreSyncService().upsertStudent(inserted); // fire-and-forget

    return id;
  }

  Future<Student?> getStudentByLrn(String lrn) async {
    final db = await database;
    final rows =
        await db.query('students', where: 'lrn = ?', whereArgs: [lrn]);
    if (rows.isEmpty) return null;
    return Student.fromMap(rows.first);
  }

  Future<bool> studentExists(String lrn) async {
    final db = await database;
    final result =
        await db.query('students', where: 'lrn = ?', whereArgs: [lrn]);
    return result.isNotEmpty;
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final maps = await db.query('students', orderBy: 'created_at DESC');
    return maps.map(Student.fromMap).toList();
  }

  // ─── Temp / walk-in students ───────────────────────────────────────────────

  Future<List<StudentPaymentInfo>> getUnlinkedTempStudents() async {
    final db = await database;
    final rows = await db.query('students',
        where: 'is_temp = 1', orderBy: 'created_at DESC');
    final totalFee = await getTotalFee();
    final List<StudentPaymentInfo> result = [];
    for (final row in rows) {
      final s = Student.fromMap(row);
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
  }) async {
    final db = await database;
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
    await db.delete('students',
        where: 'id = ?', whereArgs: [tempStudentId]);
    return true;
  }

  Future<bool> assignLrnToTemp({
    required int tempStudentId,
    required String realLrn,
  }) async {
    final db = await database;
    final conflict =
        await db.query('students', where: 'lrn = ?', whereArgs: [realLrn]);
    if (conflict.isNotEmpty) return false;
    await db.update(
      'students',
      {'lrn': realLrn, 'is_temp': 0},
      where: 'id = ?',
      whereArgs: [tempStudentId],
    );
    return true;
  }

  // ─── Payments ──────────────────────────────────────────────────────────────

  Future<Payment> addPayment(Payment payment) async {
    final db = await database;
    final txn = payment.transactionNumber.isNotEmpty
        ? payment.transactionNumber
        : await _nextTransactionNumber(db);
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
    map['synced'] = 0; // ensure unsynced on insert
    final id = await db.insert('payments', map);

    // Add to pending_sync queue
    await db.insert(
      'pending_sync',
      {'payment_id': id, 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final saved = Payment(
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

    // Attempt immediate sync; if offline the SDK queues it
    FirestoreSyncService().upsertPayment(saved, onSynced: () async {
      await markPaymentSynced(id);
    });

    return saved;
  }

  /// Called by FirestoreSyncService after a successful Firestore write.
  Future<void> markPaymentSynced(int paymentId) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.* FROM payments p
      INNER JOIN pending_sync ps ON ps.payment_id = p.id
      WHERE ps.synced = 0
    ''');
    return maps.map(Payment.fromMap).toList();
  }

  /// Returns count of payments waiting to sync (for UI badge).
  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pending_sync WHERE synced = 0');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<Payment>> getPaymentsByProcessor(String uid) async {
    final db = await database;
    final maps = await db.query(
      'payments',
      where: 'processed_by_uid = ?',
      whereArgs: [uid],
      orderBy: 'created_at DESC',
    );
    return maps.map(Payment.fromMap).toList();
  }

  Future<double> getAmountPaidForStudent(int studentId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payments WHERE student_id = ?',
        [studentId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ─── Merging local + Firestore payments ───────────────────────────────────
  //
  // When a student's payment info is requested, we:
  //   1. Load local payments from SQLite.
  //   2. Load remote payments from Firestore (by studentId).
  //   3. Merge by transaction_number — local wins for unsynced, remote fills gaps.
  //
  // This means if Teacher A collected offline and Teacher B looks up the same
  // student while online, Teacher B still sees ALL payments correctly.

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

  /// Returns merged payments: union of local SQLite + remote Firestore,
  /// deduplicated by transaction_number. Local unsynced payments are always
  /// included; remote-only payments are inserted into local DB to keep it fresh.
  Future<List<Payment>> getMergedPaymentsForStudent(int studentId) async {
    final localPayments = await getPaymentsForStudent(studentId);
    List<Payment> remotePayments = [];

    try {
      remotePayments =
          await FirestoreSyncService().fetchPaymentsForStudent(studentId);
    } catch (_) {
      // Offline or Firestore unavailable — fall back to local only
    }

    // Build a map keyed by transaction_number (or id as fallback)
    final Map<String, Payment> merged = {};

    // Remote payments go in first (they're the source of truth for synced data)
    for (final p in remotePayments) {
      final key = p.transactionNumber.isNotEmpty
          ? p.transactionNumber
          : 'remote-${p.id}';
      merged[key] = p;
    }

    // Local payments override (they may be newer / unsynced)
    for (final p in localPayments) {
      final key = p.transactionNumber.isNotEmpty
          ? p.transactionNumber
          : 'local-${p.id}';
      merged[key] = p;
    }

    // Insert any remote-only payments into local DB so this device stays current
    final localTxnNumbers =
        localPayments.map((p) => p.transactionNumber).toSet();
    for (final p in remotePayments) {
      if (!localTxnNumbers.contains(p.transactionNumber) &&
          p.transactionNumber.isNotEmpty) {
        await _insertRemotePaymentLocally(p);
      }
    }

    final result = merged.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  /// Inserts a payment fetched from Firestore into local SQLite (marked as synced).
  Future<void> _insertRemotePaymentLocally(Payment payment) async {
    final db = await database;
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
    final db = await database;
    final totalFee = await getTotalFee();

    final rows = await db.rawQuery(
        'SELECT DISTINCT student_id FROM payments WHERE processed_by_uid = ?',
        [uid]);

    final List<StudentPaymentInfo> result = [];
    for (final row in rows) {
      final studentId = row['student_id'] as int;
      final studentRows = await db
          .query('students', where: 'id = ?', whereArgs: [studentId]);
      if (studentRows.isEmpty) continue;

      final student = Student.fromMap(studentRows.first);
      final payments = await getPaymentsForStudent(studentId);
      final amountPaid = payments.fold<double>(0, (s, p) => s + p.amount);
      result.add(StudentPaymentInfo(
          student: student,
          totalFee: totalFee,
          amountPaid: amountPaid,
          payments: payments));
    }
    return result;
  }

  Future<int> getTotalStudentCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM students');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalCollected() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT SUM(amount) as total FROM payments');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalCollectedByProcessor(String uid) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payments WHERE processed_by_uid = ?',
        [uid]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, int>> getCountByGrade() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT grade, COUNT(*) as count FROM students GROUP BY grade ORDER BY grade');
    return {
      for (var row in result)
        row['grade'] as String: row['count'] as int
    };
  }

  // AFTER
  Future<List<AuditLog>> getAllAuditLogs() async {
    final db = await database;
    final rows = await db.query(
      'audit_logs',
      orderBy: 'created_at DESC',
    );
    return rows.map(AuditLog.fromMap).toList();
  }

  Future<List<AuditLog>> getAuditLogsByUser(String uid) async {
    final db = await database;
    final rows = await db.query(
      'audit_logs',
      where: 'processed_by_uid = ?',
      whereArgs: [uid],
      orderBy: 'created_at DESC',
    );
    return rows.map(AuditLog.fromMap).toList();
  }

  Future<List<AuditLog>> getUnsyncedAuditLogs() async {
    final db = await database;
    final rows = await db.query(
      'audit_logs',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(AuditLog.fromMap).toList();
  }

  Future<void> markAuditLogSynced(int id) async {
    final db = await database;
    await db.update(
      'audit_logs',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final db = await database;
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