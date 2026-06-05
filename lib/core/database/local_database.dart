import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

class LocalDatabase {
  Database? _database;

  Future<Database> get instance async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'lumbar_rhythm.db');
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );

    _database = database;
    return database;
  }

  Future<void> close() async {
    final database = _database;
    if (database != null) {
      await database.close();
      _database = null;
    }
  }

  Future<String?> readSetting(String key) async {
    final database = await instance;
    final rows = await database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as String?;
  }

  Future<void> writeSetting(String key, String value) async {
    final database = await instance;
    await database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertRecord({
    required String type,
    required String? note,
    required DateTime createdAt,
  }) async {
    final database = await instance;
    return database.insert(
      'records',
      {
        'type': type,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      },
    );
  }

  Future<List<Map<String, Object?>>> readRecordsCreatedBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    final database = await instance;
    return database.query(
      'records',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, Object?>>> readAllRecords() async {
    final database = await instance;
    return database.query('records', orderBy: 'created_at DESC');
  }

  Future<Map<String, String>> readAllSettings() async {
    final database = await instance;
    final rows = await database.query('settings');

    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> deleteAllLocalData() async {
    final database = await instance;
    await database.transaction((transaction) async {
      await transaction.delete('records');
      await transaction.delete('settings');
    });
  }
}
