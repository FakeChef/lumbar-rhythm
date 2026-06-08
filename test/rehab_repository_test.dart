import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/database/local_database.dart';
import 'package:lumbar_rhythm/features/actions/data/rehab_repository.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late String dbPath;
  late LocalDatabase database;
  late SqfliteRehabRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbPath = p.join(await databaseFactory.getDatabasesPath(), 'rehab.db');
    await databaseFactory.deleteDatabase(dbPath);
    database = LocalDatabase(databasePath: dbPath);
    repository = SqfliteRehabRepository(database);
  });

  tearDown(() async {
    await database.close();
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('loads built-in rehab actions and saves a rehab log', () async {
    final actions = await repository.loadActions();

    final log = await repository.addLog(
      action: actions.first,
      amount: '8',
      unit: '分钟',
      reaction: RehabReaction.muchWorse,
      symptomTag: '腿麻',
      preSymptomScore: 2,
      postSymptomScore: 5,
      note: '今天量偏多',
      createdAt: DateTime(2026, 6, 6, 9),
    );
    final logs = await repository.loadToday(now: DateTime(2026, 6, 6, 12));

    expect(actions.length, 25);
    expect(log.reaction, RehabReaction.muchWorse);
    expect(log.symptomTag, '腿麻');
    expect(log.symptomTags, ['腿麻']);
    expect(log.preSymptomScore, 2);
    expect(log.postSymptomScore, 5);
    expect(logs.single.note, '今天量偏多');
  });
}
