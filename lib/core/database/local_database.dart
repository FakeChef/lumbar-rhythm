import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

class LocalDatabase {
  LocalDatabase({String? databasePath}) : _databasePath = databasePath;

  static const schemaVersion = 2;

  final String? _databasePath;
  Database? _database;

  Future<Database> get instance async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final path =
        _databasePath ?? p.join(await getDatabasesPath(), 'lumbar_rhythm.db');
    final database = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        await _createV1Tables(db);
        await _createV2Tables(db);
        await _seedRehabActions(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
          await _seedRehabActions(db);
        }
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

  Future<void> deleteRecord(int id) async {
    final database = await instance;
    await database.delete(
      'records',
      where: 'id = ?',
      whereArgs: [id],
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
      await transaction.delete('posture_sessions');
      await transaction.delete('rehab_logs');
      await transaction.delete('settings');
      await transaction.delete('rehab_actions');
      await _seedRehabActions(transaction);
    });
  }

  Future<int> insertPostureSession({
    required String type,
    required DateTime startedAt,
  }) async {
    final database = await instance;
    return database.insert(
      'posture_sessions',
      {
        'type': type,
        'started_at': startedAt.toIso8601String(),
      },
    );
  }

  Future<Map<String, Object?>?> readOpenPostureSession() async {
    final database = await instance;
    final rows = await database.query(
      'posture_sessions',
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> closeOpenPostureSessions({
    required DateTime endedAt,
  }) async {
    final database = await instance;
    final rows = await database.query(
      'posture_sessions',
      where: 'ended_at IS NULL',
    );
    for (final row in rows) {
      final startedAt = DateTime.parse(row['started_at'] as String);
      final durationSeconds = endedAt.difference(startedAt).inSeconds;
      await database.update(
        'posture_sessions',
        {
          'ended_at': endedAt.toIso8601String(),
          'duration_seconds': durationSeconds < 0 ? 0 : durationSeconds,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    return rows.length;
  }

  Future<List<Map<String, Object?>>> readAllPostureSessions() async {
    final database = await instance;
    return database.query('posture_sessions', orderBy: 'started_at DESC');
  }

  Future<List<Map<String, Object?>>> readRehabActions() async {
    final database = await instance;
    await _ensureRehabActionsSeeded(database);
    return database.query('rehab_actions', orderBy: 'sort_order ASC');
  }

  Future<List<Map<String, Object?>>> readAllRehabActions() async {
    final database = await instance;
    await _ensureRehabActionsSeeded(database);
    return database.query('rehab_actions', orderBy: 'sort_order ASC');
  }

  Future<int> insertRehabLog({
    required int actionId,
    required String amount,
    required String unit,
    required String reaction,
    required String? symptomTag,
    required String? note,
    required DateTime createdAt,
  }) async {
    final database = await instance;
    return database.insert(
      'rehab_logs',
      {
        'action_id': actionId,
        'amount': amount,
        'unit': unit,
        'reaction': reaction,
        'symptom_tag': symptomTag,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      },
    );
  }

  Future<List<Map<String, Object?>>> readRehabLogsCreatedBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    final database = await instance;
    return database.query(
      'rehab_logs',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, Object?>>> readAllRehabLogs() async {
    final database = await instance;
    return database.query('rehab_logs', orderBy: 'created_at DESC');
  }

  Future<void> _createV1Tables(DatabaseExecutor db) async {
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
  }

  Future<void> _createV2Tables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS posture_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_seconds INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rehab_actions (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        default_unit TEXT NOT NULL,
        guidance TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rehab_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_id INTEGER NOT NULL,
        amount TEXT NOT NULL,
        unit TEXT NOT NULL,
        reaction TEXT NOT NULL,
        symptom_tag TEXT,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureRehabActionsSeeded(DatabaseExecutor db) async {
    final rows = await db.query('rehab_actions', limit: 1);
    if (rows.isEmpty) {
      await _seedRehabActions(db);
    }
  }

  Future<void> _seedRehabActions(DatabaseExecutor db) async {
    const actions = [
      (1, '步行', '分钟', '按自己舒适节奏记录一次步行。'),
      (2, '室内慢走', '分钟', '在室内缓慢走动，留意身体反应。'),
      (3, '腹式呼吸', '次', '选择舒适姿势，放慢呼吸并记录完成量。'),
      (4, '肩胛后收', '次', '轻轻向后收肩胛，避免憋气和猛发力。'),
      (5, '坐站转换', '次', '从坐到站缓慢转换，记录完成次数。'),
      (6, '仰卧放松', '分钟', '仰卧或舒适躺姿休息，记录持续时间。'),
      (7, '腹横肌轻收紧', '次', '轻柔收紧核心，保持自然呼吸。'),
      (8, 'Bird-dog 简化版', '次', '降低幅度，按可接受的范围记录。'),
      (9, '侧桥简化版', '次', '采用简化支撑方式，记录完成次数。'),
      (10, '一脚垫高放松站姿', '分钟', '一脚轻放垫高物，观察站姿放松感。'),
    ];

    for (final action in actions) {
      await db.insert(
        'rehab_actions',
        {
          'id': action.$1,
          'name': action.$2,
          'default_unit': action.$3,
          'guidance': action.$4,
          'sort_order': action.$1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
