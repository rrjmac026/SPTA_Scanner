import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Core database service handling initialization and versioning.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

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
      version: 8,
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
          final txn = await nextTransactionNumber(db);
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

    if (oldVersion < 7) {
      try {
        await db.execute(
            'ALTER TABLE payments ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_sync (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payment_id INTEGER NOT NULL UNIQUE,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

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

  /// Generates the next transaction number.
  Future<String> nextTransactionNumber(DatabaseExecutor db) async {
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

  /// Generates the next temporary LRN.
  Future<String> nextTempLrn(DatabaseExecutor db) async {
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
}
