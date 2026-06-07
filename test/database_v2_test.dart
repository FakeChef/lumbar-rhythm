import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/database/local_database.dart';
import 'package:lumbar_rhythm/features/actions/data/rehab_repository.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/posture/data/posture_session_repository.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbPath = p.join(await databaseFactory.getDatabasesPath(), 'test.db');
    await databaseFactory.deleteDatabase(dbPath);
  });

  tearDown(() async {
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('migrates database from v1 to v2 and keeps old records', () async {
    final v1 = await openDatabase(
      dbPath,
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
        await db.insert('records', {
          'type': 'sitting',
          'note': null,
          'created_at': DateTime(2026, 6, 6, 9).toIso8601String(),
        });
      },
    );
    await v1.close();

    final database = LocalDatabase(databasePath: dbPath);
    final db = await database.instance;
    final tables = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    );
    final tableNames = tables.map((row) => row['name']).toSet();
    final records = await database.readAllRecords();
    final rehabActions = await database.readRehabActions();

    expect(tableNames, contains('posture_sessions'));
    expect(tableNames, contains('rehab_actions'));
    expect(tableNames, contains('rehab_logs'));
    expect(records.length, 1);
    expect(rehabActions.length, actionLibrary.length);

    await database.close();
  });

  test('starts, ends, and restores posture sessions', () async {
    final database = LocalDatabase(databasePath: dbPath);
    final repository = SqflitePostureSessionRepository(database);
    final startedAt = DateTime(2026, 6, 6, 9);
    final switchedAt = DateTime(2026, 6, 6, 9, 10);

    final sitting = await repository.switchTo(
      type: PostureType.sitting,
      now: startedAt,
    );
    expect(sitting.type, PostureType.sitting);

    final restored = await repository.loadOpenSession();
    expect(restored?.type, PostureType.sitting);
    expect(restored?.startedAt, startedAt);

    final standing = await repository.switchTo(
      type: PostureType.standing,
      now: switchedAt,
    );
    final sessions = await repository.loadAll();

    expect(standing.type, PostureType.standing);
    expect(sessions.length, 2);
    expect(
      sessions.firstWhere((session) => session.id == sitting.id).endedAt,
      switchedAt,
    );
    expect(
      sessions
          .firstWhere((session) => session.id == sitting.id)
          .durationSeconds,
      600,
    );

    await database.close();
  });

  test('saves rehab logs', () async {
    final database = LocalDatabase(databasePath: dbPath);
    final repository = SqfliteRehabRepository(database);
    final actions = await repository.loadActions();

    final log = await repository.addLog(
      action: actions.first,
      amount: '12',
      unit: '分钟',
      reaction: RehabReaction.moreComfortable,
      symptomTag: '腰部',
      note: '节奏可以接受',
      createdAt: DateTime(2026, 6, 6, 10),
    );
    final today = await repository.loadToday(now: DateTime(2026, 6, 6, 12));

    expect(log.id, greaterThan(0));
    expect(today.length, 1);
    expect(today.first.reaction, RehabReaction.moreComfortable);
    expect(today.first.symptomTag, '腰部');

    await database.close();
  });
}
