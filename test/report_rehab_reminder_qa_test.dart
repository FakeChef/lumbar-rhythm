import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/data/app_data_refresh.dart';
import 'package:lumbar_rhythm/core/notifications/notification_service.dart';
import 'package:lumbar_rhythm/features/actions/application/posture_reminder_rehab_link.dart';
import 'package:lumbar_rhythm/features/actions/data/rehab_repository.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/actions/presentation/actions_page.dart';
import 'package:lumbar_rhythm/features/milestones/data/recovery_milestone_repository.dart';
import 'package:lumbar_rhythm/features/milestones/domain/recovery_milestone.dart';
import 'package:lumbar_rhythm/features/posture/data/posture_session_repository.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_summary.dart';
import 'package:lumbar_rhythm/features/recovery/data/recovery_repository.dart';
import 'package:lumbar_rhythm/features/recovery/domain/daily_recovery_note.dart';
import 'package:lumbar_rhythm/features/recovery/domain/recovery_profile.dart';
import 'package:lumbar_rhythm/features/reports/application/daily_report_controller.dart';
import 'package:lumbar_rhythm/features/reports/presentation/reports_page.dart';
import 'package:lumbar_rhythm/features/settings/data/reminder_settings_repository.dart';
import 'package:lumbar_rhythm/features/settings/domain/reminder_settings.dart';
import 'package:lumbar_rhythm/features/settings/presentation/settings_page.dart';

void main() {
  test('dailyReportController reads real posture sessions and user thresholds',
      () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final container = _reportContainer(
      postureSessions: [
        PostureSession(
          id: 1,
          type: PostureType.sitting,
          startedAt: today.add(const Duration(hours: 8)),
          endedAt: today.add(const Duration(hours: 8, minutes: 20)),
          durationSeconds: 1200,
        ),
        PostureSession(
          id: 2,
          type: PostureType.standing,
          startedAt: today.add(const Duration(hours: 9)),
          endedAt: today.add(const Duration(hours: 9, minutes: 20)),
          durationSeconds: 1200,
        ),
        PostureSession(
          id: 3,
          type: PostureType.sitting,
          startedAt: today.subtract(const Duration(days: 8)),
          endedAt: today.subtract(const Duration(days: 8)).add(
                const Duration(hours: 1),
              ),
          durationSeconds: 3600,
        ),
      ],
      settings: const ReminderSettings(
        remindersEnabled: true,
        sittingIntervalMinutes: 15,
        standingIntervalMinutes: 30,
      ),
    );
    addTearDown(container.dispose);

    final report = await container.read(dailyReportControllerProvider.future);

    expect(report.postureSummary.sessions.length, 2);
    expect(report.postureSummary.sittingTotal, const Duration(minutes: 20));
    expect(report.postureSummary.sittingOverThresholdCount, 1);
    expect(report.postureSummary.standingOverThresholdCount, 0);
    expect(report.reminderSettings.sittingIntervalMinutes, 15);

    container.read(reportPeriodProvider.notifier).state = ReportPeriod.week;
    container.invalidate(dailyReportControllerProvider);
    final weekly = await container.read(dailyReportControllerProvider.future);
    expect(weekly.postureSummary.sessions.length, 2);
  });

  test('PostureSummary uses custom reminder thresholds', () {
    final summary = PostureSummary(
      now: DateTime(2026, 6, 7, 12),
      sittingThreshold: const Duration(minutes: 15),
      standingThreshold: const Duration(minutes: 45),
      sessions: [
        PostureSession(
          id: 1,
          type: PostureType.sitting,
          startedAt: DateTime(2026, 6, 7, 8),
          endedAt: DateTime(2026, 6, 7, 8, 20),
        ),
        PostureSession(
          id: 2,
          type: PostureType.standing,
          startedAt: DateTime(2026, 6, 7, 9),
          endedAt: DateTime(2026, 6, 7, 9, 20),
        ),
      ],
    );

    expect(summary.sittingOverThresholdCount, 1);
    expect(summary.standingOverThresholdCount, 0);
  });

  testWidgets('report page shows required report sections', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _reportOverrides(
          postureSessions: [
            PostureSession(
              id: 1,
              type: PostureType.sitting,
              startedAt: today.add(const Duration(hours: 8)),
              endedAt: today.add(const Duration(hours: 8, minutes: 50)),
              durationSeconds: 3000,
              exceededSeconds: 300,
            ),
            PostureSession(
              id: 2,
              type: PostureType.walking,
              startedAt: today.add(const Duration(hours: 9)),
              endedAt: today.add(const Duration(hours: 9, minutes: 10)),
              durationSeconds: 600,
            ),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: ReportsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('康复报告'), findsOneWidget);
    expect(find.text('回顾你的坐站节奏和康复记录'), findsOneWidget);
    expect(find.text('今日康复报告'), findsOneWidget);
    expect(find.text('坐站节奏报告'), findsOneWidget);
    expect(find.text('最近 7 天趋势'), findsOneWidget);
    expect(find.text('康复动作报告'), findsOneWidget);
    expect(find.text('分享报告入口'), findsNothing);
    expect(find.text('分享报告'), findsNothing);
    expect(find.text('保存报告到相册'), findsWidgets);
    expect(find.text('免责声明'), findsNothing);
    expect(find.text('久坐超过提醒间隔'), findsOneWidget);
    expect(find.text('姿势切换次数'), findsOneWidget);
    expect(find.text(reportDisclaimerText), findsOneWidget);
  });

  test('dailyReportController refreshes when rehab data changes', () async {
    final repository = _FakeRehabRepository();
    final container = ProviderContainer(
      overrides: _reportOverrides(rehabRepository: repository),
    );
    addTearDown(container.dispose);

    final initial = await container.read(dailyReportControllerProvider.future);
    expect(initial.rehabSummary.totalCount, 0);

    await repository.addLog(
      action: actionLibrary.first,
      amount: '3',
      unit: '分钟',
      reaction: RehabReaction.noChange,
    );
    container.read(appDataRefreshProvider.notifier).state++;

    final updated = await container.read(dailyReportControllerProvider.future);
    expect(updated.rehabSummary.totalCount, 1);
  });

  test('dailyReportController refreshes when reminder settings change',
      () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final settingsRepository = _MutableReminderSettingsRepository(
      const ReminderSettings(
        remindersEnabled: true,
        sittingIntervalMinutes: 45,
        standingIntervalMinutes: 30,
      ),
    );
    final container = ProviderContainer(
      overrides: _reportOverrides(
        postureSessions: [
          PostureSession(
            id: 1,
            type: PostureType.sitting,
            startedAt: today.add(const Duration(hours: 8)),
            endedAt: today.add(const Duration(hours: 8, minutes: 20)),
            durationSeconds: 1200,
          ),
        ],
        reminderSettingsRepository: settingsRepository,
      ),
    );
    addTearDown(container.dispose);

    final initial = await container.read(dailyReportControllerProvider.future);
    expect(initial.postureSummary.sittingOverThresholdCount, 0);

    settingsRepository.settings = const ReminderSettings(
      remindersEnabled: true,
      sittingIntervalMinutes: 15,
      standingIntervalMinutes: 30,
    );
    container.read(appDataRefreshProvider.notifier).state++;

    final updated = await container.read(dailyReportControllerProvider.future);
    expect(updated.postureSummary.sittingOverThresholdCount, 1);
  });

  testWidgets('settings page shows four groups and privacy copy',
      (tester) async {
    final recoveryRepository = _FakeRecoveryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderSettingsRepositoryProvider.overrideWithValue(
            const _FakeReminderSettingsRepository(ReminderSettings.defaults),
          ),
          recoveryRepositoryProvider.overrideWithValue(recoveryRepository),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的康复资料'), findsOneWidget);
    expect(find.text('坐站提醒'), findsOneWidget);
    expect(find.text('该记录一下今天的状态了'), findsOneWidget);

    await tester.tap(find.text('手术日期、手术类型、当前目标'));
    await tester.pumpAndSettle();
    expect(find.text('患者昵称（可选）'), findsOneWidget);
    expect(find.text('昵称只保存在本地，用于今日页称呼；不要求真实姓名。'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '小林');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(recoveryRepository.savedNickname, '小林');

    await tester.scrollUntilVisible(find.text('数据管理'), 300.0);
    expect(find.text('数据管理'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('隐私与免责声明'), 300.0);
    expect(find.text('隐私与免责声明'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('无账号 / 无广告 / 无云端上传'), 300.0);
    expect(find.text('无账号 / 无广告 / 无云端上传'), findsOneWidget);
    expect(find.textContaining('无账号'), findsOneWidget);
    expect(find.textContaining('无广告'), findsOneWidget);
    expect(find.textContaining('无云端上传'), findsOneWidget);
  });

  testWidgets('settings page test reminder uses selected mode',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notificationService = _FakeNotificationService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderSettingsRepositoryProvider.overrideWithValue(
            const _FakeReminderSettingsRepository(
              ReminderSettings(
                remindersEnabled: true,
                sittingIntervalMinutes: 45,
                standingIntervalMinutes: 30,
                reminderMode: ReminderMode.alarm,
              ),
            ),
          ),
          recoveryRepositoryProvider.overrideWithValue(_FakeRecoveryRepository()),
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('提醒方式'), findsOneWidget);
    expect(find.text('响铃提醒'), findsOneWidget);

    await tester.tap(find.byTooltip('发送测试提醒'));
    await tester.pumpAndSettle();

    expect(notificationService.testReminderModes, [ReminderMode.alarm]);
  });

  test('RehabSummary uses amountValue for walking totals', () {
    final summary = RehabSummary(
      actions: actionLibrary,
      logs: [
        RehabLog(
          id: 1,
          actionId: 1,
          amount: '旧文本',
          amountValue: 3,
          unit: '分钟',
          reaction: RehabReaction.noChange,
          source: 'manual',
          createdAt: DateTime(2026, 6, 7),
        ),
      ],
    );

    expect(summary.totalAmountForActionNamed('步行'), 3);
  });

  testWidgets('rehab tab saves action log from record sheet', (tester) async {
    final repository = _FakeRehabRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rehabRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: Scaffold(body: ActionsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日康复记录'), findsOneWidget);
    expect(find.text('记录今天做了什么、做了多少、做后感觉如何。'), findsOneWidget);
    expect(find.byKey(const ValueKey('rehab-action-dropdown')), findsOneWidget);
    expect(find.text('今天还没有康复记录，记录一点也有价值。'), findsOneWidget);
    expect(find.text('默认目标：20 分钟'), findsNothing);
    expect(find.text('室内慢走'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rehab-action-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('腹式呼吸 · BASIC').last);
    await tester.pumpAndSettle();
    expect(find.text('腹式呼吸 · BASIC'), findsOneWidget);

    await tester.tap(find.text('记录一次'));
    await tester.pumpAndSettle();
    expect(find.text('记录 腹式呼吸'), findsOneWidget);
    expect(find.text('3分钟'), findsOneWidget);
    expect(find.text('5分钟'), findsOneWidget);

    await tester.tap(find.text('5分钟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('腰酸'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('腿麻'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('明显加重').last);
    await tester.pumpAndSettle();
    expect(find.text('建议减少量、暂停观察，必要时咨询医生或康复师。'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.addedLogs, hasLength(1));
    expect(repository.addedLogs.single.actionId, actionLibrary[8].id);
    expect(repository.addedLogs.single.amountValue, 5);
    expect(repository.addedLogs.single.unit, '分钟');
    expect(repository.addedLogs.single.reaction, RehabReaction.muchWorse);
    expect(repository.addedLogs.single.symptomTags, containsAll(['腰酸', '腿麻']));
    expect(repository.addedLogs.single.source, 'manual');
    expect(find.text('腹式呼吸'), findsWidgets);
    expect(find.text('5 分钟 · 明显加重'), findsOneWidget);
  });

  test('posture reminder link creates posture_reminder rehab logs', () async {
    final repository = _FakeRehabRepository();
    final link = PostureReminderRehabLink(repository);

    final walk = await link.recordShortWalk(createdAt: DateTime(2026, 6, 7));
    final rest = await link.recordRelaxationRest(
      createdAt: DateTime(2026, 6, 7, 1),
    );

    expect(walk.source, 'posture_reminder');
    expect(walk.amountValue, 3);
    expect(walk.unit, '分钟');
    expect(repository.actionNameFor(walk.actionId), '平地步行');
    expect(rest.source, 'posture_reminder');
    expect(repository.actionNameFor(rest.actionId), '站立姿势重置');
  });

  test('app copy avoids unsupported medical promise wording', () {
    const fixedDisclaimer = '本报告仅用于个人康复记录回顾，不作为医疗诊断或治疗依据。';
    const forbidden = [
      '治疗',
      '治愈',
      '预防复发',
      '诊断',
      '复发判断',
      '复发风险',
      '病情判断',
      '神经恢复判断',
      '纤维环愈合判断',
      '医疗建议',
    ];
    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in libFiles) {
      final text = file.readAsStringSync().replaceAll(fixedDisclaimer, '');
      for (final word in forbidden) {
        expect(text, isNot(contains(word)),
            reason: '${file.path} contains $word');
      }
    }
  });
}

ProviderContainer _reportContainer({
  List<PostureSession> postureSessions = const [],
  List<RehabLog> rehabLogs = const [],
  ReminderSettings settings = ReminderSettings.defaults,
}) {
  return ProviderContainer(
    overrides: _reportOverrides(
      postureSessions: postureSessions,
      rehabLogs: rehabLogs,
      settings: settings,
    ),
  );
}

List<Override> _reportOverrides({
  List<PostureSession> postureSessions = const [],
  List<RehabLog> rehabLogs = const [],
  ReminderSettings settings = ReminderSettings.defaults,
  RehabRepository? rehabRepository,
  ReminderSettingsRepository? reminderSettingsRepository,
}) {
  return [
    rehabRepositoryProvider.overrideWithValue(
      rehabRepository ?? _FakeRehabRepository(initialLogs: rehabLogs),
    ),
    postureSessionRepositoryProvider.overrideWithValue(
      _FakePostureRepository(postureSessions),
    ),
    recoveryRepositoryProvider.overrideWithValue(_FakeRecoveryRepository()),
    recoveryMilestoneRepositoryProvider.overrideWithValue(
      _FakeMilestoneRepository(),
    ),
    reminderSettingsRepositoryProvider.overrideWithValue(
      reminderSettingsRepository ?? _FakeReminderSettingsRepository(settings),
    ),
  ];
}

class _FakeRehabRepository implements RehabRepository {
  _FakeRehabRepository({List<RehabLog> initialLogs = const []})
      : addedLogs = [...initialLogs];

  final List<RehabLog> addedLogs;

  @override
  Future<RehabLog> addLog({
    required RehabAction action,
    required String amount,
    required String unit,
    required RehabReaction reaction,
    String? symptomTag,
    List<String> symptomTags = const [],
    String source = 'manual',
    int? preSymptomScore,
    int? postSymptomScore,
    String? note,
    DateTime? createdAt,
  }) async {
    final amountValue = double.tryParse(amount.trim()) ?? 0;
    final log = RehabLog(
      id: addedLogs.length + 1,
      actionId: action.id,
      amount: amount,
      amountValue: amountValue,
      unit: unit,
      reaction: reaction,
      source: source,
      symptomTag: symptomTag,
      symptomTags: symptomTags,
      preSymptomScore: preSymptomScore,
      postSymptomScore: postSymptomScore,
      note: note,
      createdAt: createdAt ?? DateTime.now(),
    );
    addedLogs.add(log);
    return log;
  }

  @override
  Future<List<RehabAction>> loadActions() async => actionLibrary;

  @override
  Future<List<RehabLog>> loadAllLogs() async => addedLogs;

  @override
  Future<List<RehabLog>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final today = DateTime(anchor.year, anchor.month, anchor.day);
    final start = today.subtract(Duration(days: days - 1));
    final end = today.add(const Duration(days: 1));
    return addedLogs.where((log) {
      return !log.createdAt.isBefore(start) && log.createdAt.isBefore(end);
    }).toList();
  }

  @override
  Future<List<RehabLog>> loadToday({DateTime? now}) {
    return loadRecentDays(days: 1, now: now);
  }

  String actionNameFor(int actionId) {
    return actionLibrary.firstWhere((action) => action.id == actionId).name;
  }
}

class _FakePostureRepository implements PostureSessionRepository {
  const _FakePostureRepository(this.sessions);

  final List<PostureSession> sessions;

  @override
  Future<void> endCurrent({
    DateTime? now,
    int? sittingThresholdMinutes,
    int? standingThresholdMinutes,
    String endReason = 'manual_end',
    String source = 'manual',
    String? note,
  }) async {}

  @override
  Future<List<PostureSession>> loadAll() async => sessions;

  @override
  Future<PostureSession?> loadOpenSession() async => null;

  @override
  Future<List<PostureSession>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final today = DateTime(anchor.year, anchor.month, anchor.day);
    final start = today.subtract(Duration(days: days - 1));
    final end = today.add(const Duration(days: 1));
    return sessions.where((session) {
      return !session.startedAt.isBefore(start) &&
          session.startedAt.isBefore(end);
    }).toList();
  }

  @override
  Future<List<PostureSession>> loadToday({DateTime? now}) {
    return loadRecentDays(days: 1, now: now);
  }

  @override
  Future<PostureSession> switchTo({
    required PostureType type,
    DateTime? now,
    int? sittingThresholdMinutes,
    int? standingThresholdMinutes,
    String endReason = 'user_switch',
    String source = 'manual',
    String? note,
  }) async {
    return PostureSession(id: 99, type: type, startedAt: now ?? DateTime.now());
  }
}

class _FakeRecoveryRepository implements RecoveryRepository {
  String? savedNickname;

  @override
  Future<RecoveryProfile?> loadProfile() async => null;

  @override
  Future<DailyRecoveryNote?> loadNote(DateTime date) async => null;

  @override
  Future<List<DailyRecoveryNote>> loadNotesBetween({
    required DateTime start,
    required DateTime end,
  }) async =>
      const [];

  @override
  Future<void> saveNote({
    required DateTime date,
    required OverallFeeling overallFeeling,
    required int backPainScore,
    required int legSymptomScore,
    required int fatigueScore,
    List<String> tags = const [],
    String? note,
  }) async {}

  @override
  Future<void> saveProfile({
    DateTime? surgeryDate,
    String? nickname,
    String? surgeryType,
    String? mainSegment,
    String? mainGoal,
  }) async {
    savedNickname = nickname;
  }
}

class _FakeMilestoneRepository implements RecoveryMilestoneRepository {
  @override
  Future<void> addCustom({
    required String title,
    String category = '自定义',
    DateTime? targetDate,
    String? note,
  }) async {}

  @override
  Future<void> complete(int id, {String? note}) async {}

  @override
  Future<List<RecoveryMilestone>> loadMilestones() async => const [];

  @override
  Future<void> postpone(int id, DateTime targetDate, {String? note}) async {}
}

class _FakeReminderSettingsRepository implements ReminderSettingsRepository {
  const _FakeReminderSettingsRepository(this.settings);

  final ReminderSettings settings;

  @override
  Future<ReminderSettings> load() async => settings;

  @override
  Future<void> save(ReminderSettings settings) async {}
}

class _FakeNotificationService extends NotificationService {
  final testReminderModes = <ReminderMode>[];

  @override
  Future<bool> showTestReminder({
    ReminderMode reminderMode = ReminderMode.soft,
  }) async {
    testReminderModes.add(reminderMode);
    return true;
  }
}

class _MutableReminderSettingsRepository implements ReminderSettingsRepository {
  _MutableReminderSettingsRepository(this.settings);

  ReminderSettings settings;

  @override
  Future<ReminderSettings> load() async => settings;

  @override
  Future<void> save(ReminderSettings settings) async {
    this.settings = settings;
  }
}
