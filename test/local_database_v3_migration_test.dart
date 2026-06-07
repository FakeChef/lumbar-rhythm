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
}
