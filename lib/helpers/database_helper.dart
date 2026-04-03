import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class Student {
  final int? id;
  final String name;
  final String lrn;
  final String grade;
  final String createdAt;

  Student({
    this.id,
    required this.name,
    required this.lrn,
    required this.grade,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'lrn': lrn,
        'grade': grade,
        'created_at': createdAt,
      };

  factory Student.fromMap(Map<String, dynamic> map) => Student(
        id: map['id'] as int?,
        name: map['name'] as String,
        lrn: map['lrn'] as String,
        grade: map['grade'] as String? ?? '',
        createdAt: map['created_at'] as String,
      );
}

class Payment {
  final int? id;
  final int studentId;
  final double amount;
  final String note;
  final String createdAt;

  Payment({
    this.id,
    required this.studentId,
    required this.amount,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'amount': amount,
        'note': note,
        'created_at': createdAt,
      };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as int?,
        studentId: map['student_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String? ?? '',
        createdAt: map['created_at'] as String,
      );
}

/// A convenience wrapper that combines a Student with their payment summary.
class StudentPaymentInfo {
  final Student student;
  final double totalFee;
  final double amountPaid;
  final List<Payment> payments;

  StudentPaymentInfo({
    required this.student,
    required this.totalFee,
    required this.amountPaid,
    required this.payments,
  });

  double get remainingBalance => (totalFee - amountPaid).clamp(0, double.infinity);
  bool get isFullyPaid => remainingBalance <= 0;
  String get paymentStatus => isFullyPaid ? 'Fully Paid' : (amountPaid > 0 ? 'Partial' : 'Unpaid');
}

// ─── DatabaseHelper ───────────────────────────────────────────────────────────

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
    // Students table — no amount column; payments are in their own table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        lrn TEXT NOT NULL UNIQUE,
        grade TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // Per-student installment payments
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

    // App-wide settings (key-value store)
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default total SPTA fee
    await db.insert('settings', {'key': 'total_fee', 'value': '750'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Migrate from old schema: create new tables if missing
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

      // Migrate old amount column data into payments table
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

      // Insert default fee if not present
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
    final rows = await db.query('settings', where: 'key = ?', whereArgs: ['total_fee']);
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
    final existing = await db.query('students', where: 'lrn = ?', whereArgs: [student.lrn]);
    if (existing.isNotEmpty) return null;
    return await db.insert('students', student.toMap());
  }

  Future<Student?> getStudentByLrn(String lrn) async {
    final db = await database;
    final rows = await db.query('students', where: 'lrn = ?', whereArgs: [lrn]);
    if (rows.isEmpty) return null;
    return Student.fromMap(rows.first);
  }

  Future<bool> studentExists(String lrn) async {
    final db = await database;
    final result = await db.query('students', where: 'lrn = ?', whereArgs: [lrn]);
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
        'SELECT SUM(amount) as total FROM payments WHERE student_id = ?', [studentId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ─── Aggregates ────────────────────────────────────────────────────────────

  /// Full info for one student (by LRN).
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

  /// Full info for all students.
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
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM students');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalCollected() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM payments');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, int>> getCountByGrade() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT grade, COUNT(*) as count FROM students GROUP BY grade ORDER BY grade');
    return {for (var row in result) row['grade'] as String: row['count'] as int};
  }
}