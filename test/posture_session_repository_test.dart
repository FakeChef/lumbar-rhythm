import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/database/local_database.dart';
import 'package:lumbar_rhythm/features/posture/data/posture_session_repository.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late String dbPath;
  late LocalDatabase database;
  late SqflitePostureSessionRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbPath = p.join(await databaseFactory.getDatabasesPath(), 'posture.db');
    await databaseFactory.deleteDatabase(dbPath);
    database = LocalDatabase(databasePath: dbPath);
    repository = SqflitePostureSessionRepository(database);
  });

  tearDown(() async {
    await database.close();
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('does not create a new session when tapping current posture again',
      () async {
    final startedAt = DateTime(2026, 6, 6, 9);

    final first = await repository.switchTo(
      type: PostureType.sitting,
      now: startedAt,
    );
    final second = await repository.switchTo(
      type: PostureType.sitting,
      now: startedAt.add(const Duration(minutes: 5)),
    );
    final all = await repository.loadAll();

    expect(second.id, first.id);
    expect(all.length, 1);
    expect(all.single.endedAt, isNull);
  });

  test('ends current open session', () async {
    final startedAt = DateTime(2026, 6, 6, 9);
    final endedAt = DateTime(2026, 6, 6, 9, 20);

    await repository.switchTo(type: PostureType.standing, now: startedAt);
    await repository.endCurrent(now: endedAt);
    final open = await repository.loadOpenSession();
    final all = await repository.loadAll();

    expect(open, isNull);
    expect(all.single.endedAt, endedAt);
    expect(all.single.durationSeconds, 1200);
  });
}
