import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        lrn TEXT NOT NULL UNIQUE,
        grade TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert('settings', {'key': 'total_fee', 'value': '750'});
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
            });
          }
        }
      } catch (_) {}
      await db.insert(
        'settings',
        {'key': 'total_fee', 'value': '750'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
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
    await db.insert(
      'settings',
      {'key': 'total_fee', 'value': fee.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Students ──────────────────────────────────────────────────────────────

  /// Returns the inserted student's id, or null if LRN already exists.
  Future<int?> insertStudent(Student student) async {
    final db = await database;
    final existing =
        await db.query('students', where: 'lrn = ?', whereArgs: [student.lrn]);
    if (existing.isNotEmpty) return null;
    return await db.insert('students', student.toMap());
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

  // ─── Payments ──────────────────────────────────────────────────────────────

  Future<Payment> addPayment(Payment payment) async {
    final db = await database;
    final id = await db.insert('payments', payment.toMap());
    return Payment(
      id: id,
      studentId: payment.studentId,
      amount: payment.amount,
      note: payment.note,
      createdAt: payment.createdAt,
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

  Future<double> getAmountPaidForStudent(int studentId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payments WHERE student_id = ?',
        [studentId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ─── Aggregates ────────────────────────────────────────────────────────────

  Future<StudentPaymentInfo?> getStudentPaymentInfo(String lrn) async {
    final student = await getStudentByLrn(lrn);
    if (student == null) return null;
    final totalFee = await getTotalFee();
    final payments = await getPaymentsForStudent(student.id!);
    final amountPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    return StudentPaymentInfo(
      student: student,
      totalFee: totalFee,
      amountPaid: amountPaid,
      payments: payments,
    );
  }

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
        payments: payments,
      ));
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

  Future<Map<String, int>> getCountByGrade() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT grade, COUNT(*) as count FROM students GROUP BY grade ORDER BY grade');
    return {
      for (var row in result) row['grade'] as String: row['count'] as int
    };
  }
}