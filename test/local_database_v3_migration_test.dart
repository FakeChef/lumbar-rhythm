import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/database/local_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v2 rehab log amount migrates to amount value in v3', () async {
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      'migration_v3.db',
    );
    await databaseFactory.deleteDatabase(dbPath);

    final v2 = await openDatabase(
      dbPath,
      version: 2,
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
        await db.execute('''
          CREATE TABLE posture_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            duration_seconds INTEGER
          )
        ''');
        await db.insert('posture_sessions', {
          'type': 'sitting',
          'started_at': DateTime(2026, 6, 6, 8).toIso8601String(),
          'ended_at': DateTime(2026, 6, 6, 8, 20).toIso8601String(),
          'duration_seconds': 1200,
        });
        await db.execute('''
          CREATE TABLE rehab_actions (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            default_unit TEXT NOT NULL,
            guidance TEXT NOT NULL,
            sort_order INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE rehab_logs (
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
        await db.insert('rehab_logs', {
          'action_id': 1,
          'amount': '18.5',
          'unit': '分钟',
          'reaction': 'noChange',
          'symptom_tag': '腰酸',
          'note': null,
          'created_at': DateTime(2026, 6, 6).toIso8601String(),
        });
      },
    );
    await v2.close();

    final database = LocalDatabase(databasePath: dbPath);
    final rows = await database.readAllRehabLogs();
    final postureRows = await database.readAllPostureSessions();

    expect(rows.single['amount_value'], 18.5);
    expect(rows.single['source'], 'manual');
    expect(rows.single['symptom_tags'], '["腰酸"]');
    expect(rows.single.containsKey('pre_symptom_score'), isTrue);
    expect(rows.single.containsKey('post_symptom_score'), isTrue);
    expect(postureRows.single['type'], 'sitting');
    expect(postureRows.single['duration_seconds'], 1200);
    expect(postureRows.single['exceeded_seconds'], 0);
    expect(postureRows.single.containsKey('threshold_seconds'), isTrue);
    expect(postureRows.single.containsKey('end_reason'), isTrue);
    expect(postureRows.single['source'], 'manual');
    final profileColumns =
        await (await database.instance).rawQuery('PRAGMA table_info(recovery_profile)');
    expect(profileColumns.any((row) => row['name'] == 'nickname'), isTrue);

    await database.close();
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('old user data survives upgrade to current schema', () async {
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      'migration_current.db',
    );
    await databaseFactory.deleteDatabase(dbPath);

    final oldDatabase = await openDatabase(
      dbPath,
      version: 3,
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
        await db.execute('''
          CREATE TABLE posture_sessions (
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
        await db.insert('posture_sessions', {
          'type': 'standing',
          'started_at': DateTime(2026, 6, 7, 8).toIso8601String(),
          'ended_at': DateTime(2026, 6, 7, 8, 30).toIso8601String(),
          'duration_seconds': 1800,
          'source': 'manual',
        });
        await db.execute('''
          CREATE TABLE rehab_actions (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            default_unit TEXT NOT NULL,
            guidance TEXT NOT NULL,
            sort_order INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE rehab_logs (
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
        await db.insert('rehab_logs', {
          'action_id': 1,
          'amount': '8',
          'amount_value': 8.0,
          'unit': '分钟',
          'reaction': 'noChange',
          'source': 'manual',
          'created_at': DateTime(2026, 6, 7, 9).toIso8601String(),
        });
        await db.execute('''
          CREATE TABLE recovery_profile (
            id INTEGER PRIMARY KEY,
            surgery_date TEXT,
            surgery_type TEXT,
            main_segment TEXT,
            main_goal TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.insert('recovery_profile', {
          'id': 1,
          'surgery_date': DateTime(2026, 6).toIso8601String(),
          'surgery_type': '可选',
          'main_segment': 'L4-L5',
          'main_goal': '稳定记录',
          'created_at': DateTime(2026, 6, 7).toIso8601String(),
          'updated_at': DateTime(2026, 6, 7).toIso8601String(),
        });
        await db.execute('''
          CREATE TABLE daily_recovery_notes (
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
        await db.insert('daily_recovery_notes', {
          'date': '2026-06-07',
          'overall_feeling': 'same',
          'back_pain_score': 2,
          'leg_symptom_score': 1,
          'fatigue_score': 3,
          'tags': '["腰酸"]',
          'note': '旧记录',
          'created_at': DateTime(2026, 6, 7).toIso8601String(),
          'updated_at': DateTime(2026, 6, 7).toIso8601String(),
        });
      },
    );
    await oldDatabase.close();

    final database = LocalDatabase(databasePath: dbPath);
    final postureRows = await database.readAllPostureSessions();
    final rehabRows = await database.readAllRehabLogs();
    final profile = await database.readRecoveryProfile();
    final notes = await database.readAllDailyRecoveryNotes();
    final profileColumns =
        await (await database.instance).rawQuery('PRAGMA table_info(recovery_profile)');

    expect(postureRows.single['type'], 'standing');
    expect(rehabRows.single['action_id'], 1);
    expect(rehabRows.single['amount_value'], 8.0);
    expect(profile?['main_goal'], '稳定记录');
    expect(notes.single['note'], '旧记录');
    expect(profileColumns.any((row) => row['name'] == 'nickname'), isTrue);

    await database.close();
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('migration code does not drop core user tables', () {
    final source = File('lib/core/database/local_database.dart').readAsStringSync();
    const coreTables = [
      'posture_sessions',
      'rehab_logs',
      'recovery_profile',
      'daily_recovery_notes',
      'settings',
    ];

    for (final table in coreTables) {
      expect(
        source.toUpperCase(),
        isNot(contains('DROP TABLE $table'.toUpperCase())),
      );
    }
    expect(source, contains('ALTER TABLE'));
  });
}
