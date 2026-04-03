import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class Student {
  final int? id;
  final String name;
  final String lrn;
  final String paymentStatus;
  final String createdAt;

  Student({
    this.id,
    required this.name,
    required this.lrn,
    this.paymentStatus = 'Paid',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lrn': lrn,
      'payment_status': paymentStatus,
      'created_at': createdAt,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      lrn: map['lrn'] as String,
      paymentStatus: map['payment_status'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

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
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'spta_payments.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        lrn TEXT NOT NULL UNIQUE,
        payment_status TEXT NOT NULL DEFAULT 'Paid',
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Returns true if inserted, false if already exists
  Future<bool> insertStudent(Student student) async {
    final db = await database;

    // Check if LRN already exists
    final existing = await db.query(
      'students',
      where: 'lrn = ?',
      whereArgs: [student.lrn],
    );

    if (existing.isNotEmpty) {
      return false; // Already exists
    }

    await db.insert(
      'students',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return true; // Successfully inserted
  }

  Future<bool> studentExists(String lrn) async {
    final db = await database;
    final result = await db.query(
      'students',
      where: 'lrn = ?',
      whereArgs: [lrn],
    );
    return result.isNotEmpty;
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final maps = await db.query('students', orderBy: 'created_at DESC');
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  Future<int> getTotalPaid() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM students');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
