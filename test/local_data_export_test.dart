import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/database/local_database.dart';
import 'package:lumbar_rhythm/features/settings/data/local_data_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      'local_backup_test.db',
    );
    await databaseFactory.deleteDatabase(dbPath);
  });

  tearDown(() async {
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('local backup payload contains metadata and core tables', () async {
    final database = LocalDatabase(databasePath: dbPath);
    await _seedCoreUserData(database);

    final payload = await LocalDataRepository(database).buildBackupPayload(
      exportedAt: DateTime(2026, 6, 7, 12),
    );
    final metadata = payload['metadata'] as Map<String, Object?>;

    expect(metadata['appName'], 'Lumbar Rhythm');
    expect(metadata['exportedAt'], '2026-06-07T12:00:00.000');
    expect(metadata['schemaVersion'], LocalDatabase.schemaVersion);
    expect(metadata['backupVersion'], LocalDataRepository.backupVersion);
    expect(payload['settings'], isA<Map<String, Object?>>());
    expect(payload['recovery_profile'], isA<Map<String, Object?>>());
    expect(payload['daily_recovery_notes'], isA<List<Object?>>());
    expect(payload['posture_sessions'], isA<List<Object?>>());
    expect(payload['rehab_actions'], isA<List<Object?>>());
    expect(payload['activity_master'], isA<List<Object?>>());
    expect(payload['rehab_logs'], isA<List<Object?>>());
    expect(payload['recovery_milestones'], isA<List<Object?>>());
    expect(payload['privacy_note'], contains('does not upload health data'));

    await database.close();
  });

  test('local backup import restores core user data', () async {
    final sourceDatabase = LocalDatabase(databasePath: dbPath);
    await _seedCoreUserData(sourceDatabase);
    final repository = LocalDataRepository(sourceDatabase);
    final payload = await repository.buildBackupPayload(
      exportedAt: DateTime(2026, 6, 7, 12),
    );
    await sourceDatabase.close();

    final restoredPath = p.join(
      await databaseFactory.getDatabasesPath(),
      'local_backup_restore_test.db',
    );
    await databaseFactory.deleteDatabase(restoredPath);
    final restoredDatabase = LocalDatabase(databasePath: restoredPath);
    await LocalDataRepository(restoredDatabase).importBackupPayload(payload);

    final settings = await restoredDatabase.readAllSettings();
    final profile = await restoredDatabase.readRecoveryProfile();
    final notes = await restoredDatabase.readAllDailyRecoveryNotes();
    final postureSessions = await restoredDatabase.readAllPostureSessions();
    final rehabLogs = await restoredDatabase.readAllRehabLogs();
    final milestones = await restoredDatabase.readAllRecoveryMilestones();

    expect(settings['reminders_enabled'], 'true');
    expect(profile?['nickname'], '小林');
    expect(notes.single['date'], '2026-06-07');
    expect(postureSessions.single['type'], 'sitting');
    expect(rehabLogs.single['action_id'], 1);
    expect(milestones, isNotEmpty);

    await restoredDatabase.close();
    await databaseFactory.deleteDatabase(restoredPath);
  });

  test('backup import rejects missing metadata', () async {
    final database = LocalDatabase(databasePath: dbPath);
    final repository = LocalDataRepository(database);

    expect(
      () => repository.importBackupPayload(const {}),
      throwsA(
        isA<BackupImportException>().having(
          (error) => error.message,
          'message',
          '备份文件格式不正确。',
        ),
      ),
    );

    await database.close();
  });

  test('backup import rejects missing or invalid backup version', () async {
    final database = LocalDatabase(databasePath: dbPath);
    final repository = LocalDataRepository(database);

    expect(
      () => repository.importBackupPayload(const {'metadata': {}}),
      throwsA(isA<BackupImportException>()),
    );
    expect(
      () => repository.importBackupPayload(const {
        'metadata': {'backupVersion': '1'},
      }),
      throwsA(isA<BackupImportException>()),
    );

    await database.close();
  });

  test('backup import rejects newer backup version', () async {
    final database = LocalDatabase(databasePath: dbPath);
    final repository = LocalDataRepository(database);

    expect(
      () => repository.importBackupPayload(const {
        'metadata': {'backupVersion': LocalDataRepository.backupVersion + 1},
      }),
      throwsA(
        isA<BackupImportException>().having(
          (error) => error.message,
          'message',
          '备份版本较新，请升级 App 后再导入。',
        ),
      ),
    );

    await database.close();
  });

  test('settings page import copy warns before overwrite', () {
    final text = File('lib/features/settings/presentation/settings_page.dart')
        .readAsStringSync();

    expect(text, contains('导入会覆盖当前本地数据，请先确认已备份。'));
    expect(text, contains('导入本地备份（高级）'));
    expect(text, contains('当前版本需要粘贴本地 JSON 文件路径，后续会支持文件选择。'));
    expect(text, contains('我确认导入会覆盖当前本地数据'));
    expect(text, contains('备份文件包含你的本地康复记录，请妥善保存。App 不会自动上传备份文件。'));
  });
}

Future<void> _seedCoreUserData(LocalDatabase database) async {
  await database.writeSetting('reminders_enabled', 'true');
  await database.upsertRecoveryProfile(
    surgeryDate: DateTime(2026, 6),
    nickname: '小林',
    surgeryType: '可选',
    mainSegment: 'L4-L5',
    mainGoal: '稳定记录',
    now: DateTime(2026, 6, 7, 8),
  );
  await database.upsertDailyRecoveryNote(
    date: DateTime(2026, 6, 7),
    overallFeeling: 'same',
    backPainScore: 2,
    legSymptomScore: 1,
    fatigueScore: 3,
    tags: '["腰酸"]',
    note: '今日记录',
    now: DateTime(2026, 6, 7, 9),
  );
  await database.insertPostureSession(
    type: 'sitting',
    startedAt: DateTime(2026, 6, 7, 9),
  );
  await database.insertRehabLog(
    actionId: 1,
    amount: '10',
    amountValue: 10,
    unit: '分钟',
    reaction: 'noChange',
    symptomTag: null,
    symptomTags: null,
    source: 'manual',
    note: '备份测试',
    createdAt: DateTime(2026, 6, 7, 10),
  );
  await database.insertRecoveryMilestone(
    title: '自定义节点',
    category: '记录',
    plannedDayOffset: null,
    targetDate: DateTime(2026, 6, 30),
    status: 'planned',
    note: null,
    sortOrder: 99,
  );
}
