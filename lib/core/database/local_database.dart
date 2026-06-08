import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/actions/domain/action_item.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

class LocalDatabase {
  LocalDatabase({String? databasePath}) : _databasePath = databasePath;

  static const schemaVersion = 4;

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
        await _createV3Tables(db);
        await _seedRehabActions(db);
        await _seedRecoveryMilestones(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
          await _seedRehabActions(db);
        }
        if (oldVersion < 3) {
          await _createV3Tables(db);
          await _migrateRehabLogsToV3(db);
          await _seedRecoveryMilestones(db);
        }
        if (oldVersion < 4) {
          await _createV4Tables(db);
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
      await _clearLocalData(transaction);
      await _seedRehabActions(transaction);
      await _seedRecoveryMilestones(transaction);
    });
  }

  Future<void> replaceWithBackupData(Map<String, Object?> payload) async {
    final database = await instance;
    await database.transaction((transaction) async {
      await _clearLocalData(transaction);
      await _restoreSettings(transaction, payload['settings']);
      await _restoreRows(transaction, 'records', payload['records']);
      await _restoreRows(
        transaction,
        'posture_sessions',
        payload['posture_sessions'],
      );
      await _restoreRows(
        transaction,
        'rehab_actions',
        payload['rehab_actions'],
      );
      await _restoreRows(transaction, 'rehab_logs', payload['rehab_logs']);
      await _restoreSingleRow(
        transaction,
        'recovery_profile',
        payload['recovery_profile'],
      );
      await _restoreRows(
        transaction,
        'daily_recovery_notes',
        payload['daily_recovery_notes'],
      );
      await _restoreRows(
        transaction,
        'recovery_milestones',
        payload['recovery_milestones'],
      );
      await _ensureRehabActionsSeeded(transaction);
      await _ensureRecoveryMilestonesSeeded(transaction);
    });
  }

  Future<int> insertPostureSession({
    required String type,
    required DateTime startedAt,
    String source = 'manual',
    String? note,
  }) async {
    final database = await instance;
    return database.insert(
      'posture_sessions',
      {
        'type': type,
        'started_at': startedAt.toIso8601String(),
        'source': source,
        'note': note,
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
    required int sittingThresholdSeconds,
    required int standingThresholdSeconds,
    int? walkingThresholdSeconds,
    String endReason = 'manual_end',
    String source = 'manual',
    String? note,
  }) async {
    final database = await instance;
    final rows = await database.query(
      'posture_sessions',
      where: 'ended_at IS NULL',
    );
    for (final row in rows) {
      final startedAt = DateTime.parse(row['started_at'] as String);
      final durationSeconds = endedAt.difference(startedAt).inSeconds;
      final normalizedDuration = durationSeconds < 0 ? 0 : durationSeconds;
      final type = row['type'] as String;
      final thresholdSeconds = switch (type) {
        'sitting' => sittingThresholdSeconds,
        'standing' => standingThresholdSeconds,
        'walking' => walkingThresholdSeconds,
        _ => null,
      };
      final exceededSeconds = thresholdSeconds == null
          ? 0
          : (normalizedDuration - thresholdSeconds).clamp(0, 1 << 31).toInt();
      await database.update(
        'posture_sessions',
        {
          'ended_at': endedAt.toIso8601String(),
          'duration_seconds': normalizedDuration,
          'threshold_seconds': thresholdSeconds,
          'exceeded_seconds': exceededSeconds,
          'end_reason': endReason,
          'source': source,
          'note': note ?? row['note'],
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

  Future<List<Map<String, Object?>>> readPostureSessionsStartedBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    final database = await instance;
    return database.query(
      'posture_sessions',
      where: 'started_at >= ? AND started_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'started_at DESC',
    );
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
    required double amountValue,
    required String unit,
    required String reaction,
    required String? symptomTag,
    required String? symptomTags,
    required String source,
    int? preSymptomScore,
    int? postSymptomScore,
    required String? note,
    required DateTime createdAt,
  }) async {
    final database = await instance;
    return database.insert(
      'rehab_logs',
      {
        'action_id': actionId,
        'amount': amount,
        'amount_value': amountValue,
        'unit': unit,
        'reaction': reaction,
        'symptom_tag': symptomTag,
        'symptom_tags': symptomTags,
        'source': source,
        'pre_symptom_score': preSymptomScore,
        'post_symptom_score': postSymptomScore,
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

  Future<Map<String, Object?>?> readRecoveryProfile() async {
    final database = await instance;
    final rows = await database.query('recovery_profile', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertRecoveryProfile({
    required DateTime? surgeryDate,
    required String? nickname,
    required String? surgeryType,
    required String? mainSegment,
    required String? mainGoal,
    required DateTime now,
  }) async {
    final database = await instance;
    final existing = await readRecoveryProfile();
    await database.insert(
      'recovery_profile',
      {
        'id': 1,
        'surgery_date': surgeryDate?.toIso8601String(),
        'nickname': nickname,
        'surgery_type': surgeryType,
        'main_segment': mainSegment,
        'main_goal': mainGoal,
        'created_at': existing?['created_at'] ?? now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> readDailyRecoveryNote(DateTime date) async {
    final database = await instance;
    final rows = await database.query(
      'daily_recovery_notes',
      where: 'date = ?',
      whereArgs: [_dateKey(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertDailyRecoveryNote({
    required DateTime date,
    required String overallFeeling,
    required int backPainScore,
    required int legSymptomScore,
    required int fatigueScore,
    required String? tags,
    required String? note,
    required DateTime now,
  }) async {
    final database = await instance;
    final existing = await readDailyRecoveryNote(date);
    await database.insert(
      'daily_recovery_notes',
      {
        'date': _dateKey(date),
        'overall_feeling': overallFeeling,
        'back_pain_score': backPainScore,
        'leg_symptom_score': legSymptomScore,
        'fatigue_score': fatigueScore,
        'tags': tags,
        'note': note,
        'created_at': existing?['created_at'] ?? now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> readDailyRecoveryNotesBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    final database = await instance;
    return database.query(
      'daily_recovery_notes',
      where: 'date >= ? AND date < ?',
      whereArgs: [_dateKey(start), _dateKey(end)],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, Object?>>> readAllDailyRecoveryNotes() async {
    final database = await instance;
    return database.query('daily_recovery_notes', orderBy: 'date DESC');
  }

  Future<List<Map<String, Object?>>> readRecoveryMilestones() async {
    final database = await instance;
    await _ensureRecoveryMilestonesSeeded(database);
    return database.query('recovery_milestones', orderBy: 'sort_order ASC');
  }

  Future<int> insertRecoveryMilestone({
    required String title,
    required String category,
    required int? plannedDayOffset,
    required DateTime? targetDate,
    required String status,
    required String? note,
    required int sortOrder,
  }) async {
    final database = await instance;
    return database.insert(
      'recovery_milestones',
      {
        'title': title,
        'category': category,
        'planned_day_offset': plannedDayOffset,
        'target_date': targetDate?.toIso8601String(),
        'completed_at': null,
        'status': status,
        'note': note,
        'is_builtin': 0,
        'sort_order': sortOrder,
      },
    );
  }

  Future<void> updateRecoveryMilestone({
    required int id,
    required String status,
    required DateTime? targetDate,
    required DateTime? completedAt,
    required String? note,
  }) async {
    final database = await instance;
    await database.update(
      'recovery_milestones',
      {
        'status': status,
        'target_date': targetDate?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> readAllRecoveryMilestones() {
    return readRecoveryMilestones();
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
        duration_seconds INTEGER,
        threshold_seconds INTEGER,
        exceeded_seconds INTEGER NOT NULL DEFAULT 0,
        end_reason TEXT,
        source TEXT NOT NULL DEFAULT 'manual',
        note TEXT
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
        amount_value REAL,
        unit TEXT NOT NULL,
        reaction TEXT NOT NULL,
        symptom_tag TEXT,
        symptom_tags TEXT,
        source TEXT NOT NULL DEFAULT 'manual',
        pre_symptom_score INTEGER,
        post_symptom_score INTEGER,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createV3Tables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recovery_profile (
        id INTEGER PRIMARY KEY,
        surgery_date TEXT,
        nickname TEXT,
        surgery_type TEXT,
        main_segment TEXT,
        main_goal TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_recovery_notes (
        date TEXT PRIMARY KEY,
        overall_feeling TEXT NOT NULL,
        back_pain_score INTEGER NOT NULL,
        leg_symptom_score INTEGER NOT NULL,
        fatigue_score INTEGER NOT NULL,
        tags TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recovery_milestones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        planned_day_offset INTEGER,
        target_date TEXT,
        completed_at TEXT,
        status TEXT NOT NULL,
        note TEXT,
        is_builtin INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL
      )
    ''');
    await _addColumnIfMissing(db, 'rehab_logs', 'amount_value', 'REAL');
    await _addColumnIfMissing(
        db, 'rehab_logs', 'source', "TEXT NOT NULL DEFAULT 'manual'");
    await _addColumnIfMissing(db, 'rehab_logs', 'symptom_tags', 'TEXT');
    await _addColumnIfMissing(db, 'rehab_logs', 'pre_symptom_score', 'INTEGER');
    await _addColumnIfMissing(
        db, 'rehab_logs', 'post_symptom_score', 'INTEGER');
    await _addColumnIfMissing(
        db, 'posture_sessions', 'threshold_seconds', 'INTEGER');
    await _addColumnIfMissing(db, 'posture_sessions', 'exceeded_seconds',
        'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'posture_sessions', 'end_reason', 'TEXT');
    await _addColumnIfMissing(
        db, 'posture_sessions', 'source', "TEXT NOT NULL DEFAULT 'manual'");
    await _addColumnIfMissing(db, 'posture_sessions', 'note', 'TEXT');
    await _addColumnIfMissing(db, 'recovery_profile', 'main_segment', 'TEXT');
    await _addColumnIfMissing(db, 'daily_recovery_notes', 'tags', 'TEXT');
  }

  Future<void> _createV4Tables(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'recovery_profile', 'nickname', 'TEXT');
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _clearLocalData(DatabaseExecutor db) async {
    await db.delete('records');
    await db.delete('posture_sessions');
    await db.delete('rehab_logs');
    await db.delete('daily_recovery_notes');
    await db.delete('recovery_profile');
    await db.delete('recovery_milestones');
    await db.delete('settings');
    await db.delete('rehab_actions');
  }

  Future<void> _restoreSettings(
    DatabaseExecutor db,
    Object? settings,
  ) async {
    if (settings is! Map) return;
    for (final entry in settings.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value == null) continue;
      await db.insert(
        'settings',
        {'key': key, 'value': value.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _restoreSingleRow(
    DatabaseExecutor db,
    String table,
    Object? row,
  ) async {
    if (row is Map) {
      await _insertBackupRow(db, table, row);
    }
  }

  Future<void> _restoreRows(
    DatabaseExecutor db,
    String table,
    Object? rows,
  ) async {
    if (rows is! List) return;
    for (final row in rows) {
      if (row is Map) {
        await _insertBackupRow(db, table, row);
      }
    }
  }

  Future<void> _insertBackupRow(
    DatabaseExecutor db,
    String table,
    Map row,
  ) async {
    final columns = await _tableColumns(db, table);
    final values = <String, Object?>{};
    for (final entry in row.entries) {
      final key = entry.key;
      if (key is String && columns.contains(key)) {
        values[key] = _normalizeBackupValue(entry.value);
      }
    }
    if (values.isEmpty) return;
    await db.insert(table, values,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<String>> _tableColumns(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((row) => row['name']).whereType<String>().toSet();
  }

  Object? _normalizeBackupValue(Object? value) {
    if (value is bool) return value ? 1 : 0;
    if (value is List || value is Map) return jsonEncode(value);
    return value;
  }

  Future<void> _migrateRehabLogsToV3(DatabaseExecutor db) async {
    final rows = await db.query('rehab_logs');
    for (final row in rows) {
      final amountValue = row['amount_value'] as num?;
      if (amountValue != null) {
        continue;
      }
      final parsed = double.tryParse((row['amount'] as String?) ?? '') ?? 0;
      final symptomTag = row['symptom_tag'] as String?;
      await db.update(
        'rehab_logs',
        {
          'amount_value': parsed,
          'source': row['source'] ?? 'manual',
          'symptom_tags': symptomTag == null || symptomTag.isEmpty
              ? null
              : jsonEncode([symptomTag]),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _ensureRehabActionsSeeded(DatabaseExecutor db) async {
    final rows = await db.query('rehab_actions');
    if (rows.length < actionLibrary.length) {
      await _seedRehabActions(db);
    }
  }

  Future<void> _ensureRecoveryMilestonesSeeded(DatabaseExecutor db) async {
    final rows = await db.query(
      'recovery_milestones',
      where: 'is_builtin = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      await _seedRecoveryMilestones(db);
    }
  }

  Future<void> _seedRehabActions(DatabaseExecutor db) async {
    for (final action in actionLibrary) {
      await db.insert(
        'rehab_actions',
        {
          'id': action.id,
          'name': action.name,
          'default_unit': action.defaultUnit,
          'guidance': action.guidance,
          'sort_order': action.id,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _seedRecoveryMilestones(DatabaseExecutor db) async {
    const milestones = [
      ('第一周康复日志', '日志', 7),
      ('第一个月康复回顾', '回顾', 30),
      ('第一次复诊备注', '复诊', null),
      ('复工复学备注', '生活', null),
      ('三个月康复回顾', '回顾', 90),
    ];
    for (var index = 0; index < milestones.length; index++) {
      final item = milestones[index];
      await db.insert(
        'recovery_milestones',
        {
          'title': item.$1,
          'category': item.$2,
          'planned_day_offset': item.$3,
          'target_date': null,
          'completed_at': null,
          'status': 'planned',
          'note': null,
          'is_builtin': 1,
          'sort_order': index + 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().substring(0, 10);
  }
}
