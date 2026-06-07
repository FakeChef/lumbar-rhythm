import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/database/local_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migrates v3 to v4 by adding nickname without losing profile', () async {
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      'migration_v4.db',
    );
    await databaseFactory.deleteDatabase(dbPath);

    final v3 = await openDatabase(
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
          'surgery_date': DateTime(2026, 6, 1).toIso8601String(),
          'surgery_type': '可选',
          'main_segment': 'L4-L5',
          'main_goal': '稳定记录',
          'created_at': DateTime(2026, 6, 7).toIso8601String(),
          'updated_at': DateTime(2026, 6, 7).toIso8601String(),
        });
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
        await db.execute('''
          CREATE TABLE recovery_milestones (
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
      },
    );
    await v3.close();

    final database = LocalDatabase(databasePath: dbPath);
    final profile = await database.readRecoveryProfile();
    final profileColumns = await (await database.instance)
        .rawQuery('PRAGMA table_info(recovery_profile)');

    expect(profile?['main_goal'], '稳定记录');
    expect(profile?['main_segment'], 'L4-L5');
    expect(profileColumns.any((row) => row['name'] == 'nickname'), isTrue);

    await database.close();
    await databaseFactory.deleteDatabase(dbPath);
  });
}
