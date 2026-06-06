import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/database/local_database.dart';
import 'package:lumbar_rhythm/features/actions/data/rehab_repository.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/milestones/data/recovery_milestone_repository.dart';
import 'package:lumbar_rhythm/features/recovery/data/recovery_repository.dart';
import 'package:lumbar_rhythm/features/recovery/domain/daily_recovery_note.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late String dbPath;
  late LocalDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbPath = p.join(await databaseFactory.getDatabasesPath(), 'recovery.db');
    await databaseFactory.deleteDatabase(dbPath);
    database = LocalDatabase(databasePath: dbPath);
  });

  tearDown(() async {
    await database.close();
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('saves recovery profile with optional surgery date', () async {
    final repository = SqfliteRecoveryRepository(database);
    final surgeryDate = DateTime(2026, 6, 1);

    await repository.saveProfile(
      surgeryDate: surgeryDate,
      surgeryType: '腰椎术后',
      mainSegment: 'L4-L5',
      mainGoal: '稳定记录',
    );
    final profile = await repository.loadProfile();

    expect(profile?.surgeryDate, surgeryDate);
    expect(profile?.mainSegment, 'L4-L5');
    expect(profile?.postSurgeryDay(DateTime(2026, 6, 6)), 6);
  });

  test('saves and updates one daily recovery note per day', () async {
    final repository = SqfliteRecoveryRepository(database);
    final date = DateTime(2026, 6, 6);

    await repository.saveNote(
      date: date,
      overallFeeling: OverallFeeling.same,
      backPainScore: 3,
      legSymptomScore: 2,
      fatigueScore: 4,
      tags: ['散步后', '上午'],
      note: '上午散步',
    );
    await repository.saveNote(
      date: date,
      overallFeeling: OverallFeeling.better,
      backPainScore: 2,
      legSymptomScore: 1,
      fatigueScore: 3,
      tags: ['晚上'],
      note: '晚上更轻松',
    );
    final notes = await repository.loadNotesBetween(
      start: date,
      end: date.add(const Duration(days: 1)),
    );

    expect(notes.length, 1);
    expect(notes.single.overallFeeling, OverallFeeling.better);
    expect(notes.single.tags, ['晚上']);
    expect(notes.single.note, '晚上更轻松');
  });

  test('initializes, completes, and postpones recovery milestones', () async {
    final repository = SqfliteRecoveryMilestoneRepository(database);

    final initial = await repository.loadMilestones();
    await repository.complete(initial.first.id, note: '已回顾');
    final completed = await repository.loadMilestones();
    await repository.postpone(
      completed.last.id,
      DateTime(2026, 7, 1),
      note: '稍后记录',
    );
    final postponed = await repository.loadMilestones();

    expect(initial.length, 5);
    expect(completed.first.isCompleted, isTrue);
    expect(postponed.last.targetDate, DateTime(2026, 7, 1));
  });

  test('rehab log stores amount value, source, and multiple symptom tags',
      () async {
    final repository = SqfliteRehabRepository(database);
    final actions = await repository.loadActions();

    final log = await repository.addLog(
      action: actions.first,
      amount: '12.5',
      unit: '分钟',
      reaction: RehabReaction.noChange,
      symptomTags: ['腰酸', '疲劳'],
      source: 'manual',
      preSymptomScore: 4,
      postSymptomScore: 3,
      createdAt: DateTime(2026, 6, 6, 9),
    );
    final summary = RehabSummary(logs: [log], actions: actions);

    expect(log.amountValue, 12.5);
    expect(log.source, 'manual');
    expect(log.symptomTags, ['腰酸', '疲劳']);
    expect(log.preSymptomScore, 4);
    expect(log.postSymptomScore, 3);
    expect(summary.totalAmountForActionNamed('步行'), 12.5);
  });
}
