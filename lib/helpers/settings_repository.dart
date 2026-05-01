import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// Repository for managing settings and configuration.
class SettingsRepository {
  final DatabaseService _databaseService = DatabaseService();

  Future<Database> get _database => _databaseService.database;

  Future<double> getTotalFee() async {
    final db = await _database;
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: ['total_fee']);
    if (rows.isEmpty) return 750.0;
    return double.tryParse(rows.first['value'] as String) ?? 750.0;
  }

  Future<void> setTotalFee(double fee) async {
    final db = await _database;
    await db.insert('settings', {'key': 'total_fee', 'value': fee.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> generateTransactionNumber() async {
    final db = await _database;
    return _databaseService.nextTransactionNumber(db);
  }

  Future<String> generateTempLrn() async {
    final db = await _database;
    return _databaseService.nextTempLrn(db);
  }
}
