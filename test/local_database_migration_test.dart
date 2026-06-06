import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/database/local_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v1 database migrates to local schema v2', () async {
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      'migration.db',
    );
    await databaseFactory.deleteDatabase(dbPath);

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
      },
    );
    await v1.close();

    final localDatabase = LocalDatabase(databasePath: dbPath);
    final migrated = await localDatabase.instance;
    final tables = await migrated.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    );
    final names = tables.map((row) => row['name']).toSet();

    expect(names, contains('posture_sessions'));
    expect(names, contains('rehab_actions'));
    expect(names, contains('rehab_logs'));

    await localDatabase.close();
    await databaseFactory.deleteDatabase(dbPath);
  });
}
