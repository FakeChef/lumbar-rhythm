import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/app/lumbar_rhythm_app.dart';
import 'package:lumbar_rhythm/core/notifications/notification_service.dart';
import 'package:lumbar_rhythm/features/actions/data/rehab_repository.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/home/domain/stage_encouragement_messages.dart';
import 'package:lumbar_rhythm/features/home/presentation/home_page.dart';
import 'package:lumbar_rhythm/features/posture/application/posture_session_controller.dart';
import 'package:lumbar_rhythm/features/posture/data/posture_session_repository.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/recovery/data/recovery_repository.dart';
import 'package:lumbar_rhythm/features/recovery/domain/daily_recovery_note.dart';
import 'package:lumbar_rhythm/features/recovery/domain/recovery_profile.dart';
import 'package:lumbar_rhythm/features/shell/presentation/main_shell.dart';
import 'package:lumbar_rhythm/features/settings/data/reminder_settings_repository.dart';
import 'package:lumbar_rhythm/features/settings/domain/reminder_settings.dart';

void main() {
  testWidgets(
      'bottom navigation order is today rehab calendar reports settings',
      (tester) async {
    await _pumpApp(tester, child: const MainShell());

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    final labels = navigationBar.destinations
        .map((destination) => (destination as NavigationDestination).label)
        .toList();

    expect(labels, ['今日', '康复', '日历', '报告', '设置']);
  });

  testWidgets('shows sitting timer normal state', (tester) async {
    await _pumpHome(
      tester,
      postureRepository: _FakePostureRepository(
        openSession: _session(PostureType.sitting, minutesAgo: 10),
      ),
    );

    expect(find.byKey(const ValueKey('today-rhythm-timer')), findsOneWidget);
    final durationText = tester.widget<Text>(
      find.byKey(const ValueKey('today-rhythm-duration')),
    );
    expect(durationText.style?.fontSize, greaterThanOrEqualTo(88));
    expect(find.text('当前状态：我在坐'), findsOneWidget);
    expect(find.text('节奏正常'), findsWidgets);
    final rhythmCard = tester.widget<Card>(
      find.byKey(const ValueKey('today-rhythm-card')),
    );
    expect(rhythmCard.color, const Color(0xFF6B9AC4).withValues(alpha: 0.12));
    expect(find.textContaining('距离久坐提醒还有'), findsOneWidget);
  });

  testWidgets('shows surgery day and nickname greeting', (tester) async {
    await _pumpHome(
      tester,
      recoveryRepository: _FakeRecoveryRepository(
        profile: RecoveryProfile(
          id: 1,
          nickname: '小林',
          surgeryDate: DateTime(2026, 6, 1),
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      ),
    );

    expect(find.textContaining('小林，今天是术后第'), findsOneWidget);
    expect(find.textContaining('天。'), findsWidgets);
  });

  test('stage encouragements avoid medical boundary words', () {
    const forbidden = [
      '治疗',
      '治愈',
      '预防复发',
      '诊断',
      '复发判断',
      '复发风险',
      '病情判断',
      '医疗建议',
    ];

    expect(
        stageEncouragementMessages.keys, containsAll(['P1', 'P2', 'P3', 'P4']));
    expect(
      stageEncouragementMessages.values.fold<int>(
        0,
        (sum, messages) => sum + messages.length,
      ),
      120,
    );
    for (final messages in stageEncouragementMessages.values) {
      for (final text in messages) {
        for (final word in forbidden) {
          expect(text, isNot(contains(word)));
        }
      }
    }
  });

  testWidgets('shows near reminder and overdue states', (tester) async {
    await _pumpHome(
      tester,
      postureRepository: _FakePostureRepository(
        openSession: _session(PostureType.sitting, minutesAgo: 42),
      ),
    );
    expect(find.text('接近提醒'), findsOneWidget);

    await _pumpHome(
      tester,
      postureRepository: _FakePostureRepository(
        openSession: _session(PostureType.sitting, minutesAgo: 50),
      ),
    );
    expect(find.text('已超过建议时间'), findsOneWidget);
    expect(find.textContaining('已超过建议时间'), findsWidgets);
  });

  testWidgets('shows walking state without old resting main state',
      (tester) async {
    await _pumpHome(
      tester,
      postureRepository: _FakePostureRepository(
        openSession: _session(PostureType.walking, minutesAgo: 60),
      ),
    );
    expect(find.text('当前状态：我在走'), findsOneWidget);
    expect(find.text('已超过建议时间'), findsWidgets);
    expect(find.text('正在休息'), findsNothing);
  });

  testWidgets('shows only sitting and walking posture buttons', (tester) async {
    await _pumpHome(tester);

    expect(find.text('我在坐'), findsWidgets);
    expect(find.text('我在走'), findsWidgets);
    expect(find.text('我在站'), findsNothing);
    expect(find.text('我在休息'), findsNothing);
    expect(find.byKey(const ValueKey('today-add-rehab-log')), findsNothing);
    expect(find.byKey(const ValueKey('today-daytime-cycle-start')),
        findsOneWidget);
  });

  testWidgets('app startup requests notification permission when reminders run',
      (tester) async {
    final notificationService = _FakeNotification();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postureSessionRepositoryProvider.overrideWithValue(
            _FakePostureRepository(),
          ),
          reminderSettingsRepositoryProvider.overrideWithValue(
            _FakeReminderSettingsRepository(),
          ),
          notificationServiceProvider.overrideWithValue(notificationService),
          rehabRepositoryProvider.overrideWithValue(_FakeRehabRepository()),
          recoveryRepositoryProvider.overrideWithValue(
            _FakeRecoveryRepository(),
          ),
        ],
        child: const LumbarRhythmApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(notificationService.permissionRequests, 1);
    expect(notificationService.scheduledPostures, contains(null));
  });

  testWidgets('sitting schedules reminder and walking clears sitting reminder',
      (tester) async {
    final postureRepository = _FakePostureRepository();
    final notificationService = _FakeNotification();
    final rehabRepository = _FakeRehabRepository();
    await _pumpHome(
      tester,
      postureRepository: postureRepository,
      notificationService: notificationService,
      rehabRepository: rehabRepository,
    );

    await tester.tap(find.byKey(const ValueKey('today-posture-sitting')));
    await tester.pumpAndSettle();
    expect(
        notificationService.scheduledPostures, contains(PostureType.sitting));
    expect(postureRepository.openSession?.type, PostureType.sitting);

    await tester.tap(find.byKey(const ValueKey('today-posture-walking')));
    await tester.pumpAndSettle();
    expect(
        notificationService.scheduledPostures, contains(PostureType.walking));
    expect(postureRepository.openSession?.type, PostureType.walking);
    expect(rehabRepository.addedLogs.single.source, 'posture_session');
  });

  testWidgets('posture switch keeps record and records scheduling failures',
      (tester) async {
    final postureRepository = _FakePostureRepository();
    final notificationService = _FakeNotification(failScheduling: true);

    await _pumpHome(
      tester,
      postureRepository: postureRepository,
      notificationService: notificationService,
    );

    await tester.tap(find.byKey(const ValueKey('today-posture-sitting')));
    await tester.pumpAndSettle();

    expect(postureRepository.openSession?.type, PostureType.sitting);
    expect(notificationService.lastRecordedError, contains('schedule failed'));
  });

  test('latest posture schedule is not overwritten by stale startup cancel',
      () async {
    final postureRepository = _FakePostureRepository();
    final notificationService = _FakeNotification(delayFirstSchedule: true);
    final container = ProviderContainer(
      overrides: [
        postureSessionRepositoryProvider.overrideWithValue(postureRepository),
        reminderSettingsRepositoryProvider.overrideWithValue(
          _FakeReminderSettingsRepository(),
        ),
        notificationServiceProvider.overrideWithValue(notificationService),
        rehabRepositoryProvider.overrideWithValue(_FakeRehabRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(postureSessionControllerProvider.future);
    final switchFuture = container
        .read(postureSessionControllerProvider.notifier)
        .startSitting();
    await Future<void>.delayed(Duration.zero);

    expect(notificationService.scheduledPostures, isEmpty);

    notificationService.completeFirstSchedule();
    await switchFuture;

    expect(notificationService.scheduledPostures, [PostureType.sitting]);
  });

  test('restored overdue sitting and walking sessions fire foreground reminder',
      () async {
    for (final posture in [PostureType.sitting, PostureType.walking]) {
      final postureRepository = _FakePostureRepository(
        openSession: _session(posture, minutesAgo: 60),
      );
      final notificationService = _FakeNotification();
      final container = ProviderContainer(
        overrides: [
          postureSessionRepositoryProvider.overrideWithValue(postureRepository),
          reminderSettingsRepositoryProvider.overrideWithValue(
            _FakeReminderSettingsRepository(),
          ),
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
      );

      final restored =
          await container.read(postureSessionControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(restored?.type, posture);
      expect(notificationService.duePostures, [posture]);
      expect(notificationService.cancelledPostures, [posture]);
      expect(notificationService.scheduledPostures, [posture]);
      expect(container.read(postureReminderStatusProvider), isNotNull);
      container.dispose();
    }
  });

  testWidgets('foreground reminder retries after a failed show',
      (tester) async {
    final postureRepository = _FakePostureRepository(
      openSession: _session(PostureType.sitting, minutesAgo: 60),
    );
    final notificationService = _FakeNotification(dueResults: [false, true]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postureSessionRepositoryProvider.overrideWithValue(postureRepository),
          reminderSettingsRepositoryProvider.overrideWithValue(
            _FakeReminderSettingsRepository(),
          ),
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            ref.watch(postureSessionControllerProvider);
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    expect(notificationService.duePostures, [PostureType.sitting]);
    expect(notificationService.cancelledPostures, isEmpty);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(
      notificationService.duePostures,
      [PostureType.sitting, PostureType.sitting],
    );
    expect(notificationService.cancelledPostures, [PostureType.sitting]);
  });

  testWidgets('hides recovery overview quick entries and threshold row',
      (tester) async {
    await _pumpHome(tester);

    expect(find.text('今日恢复概览'), findsNothing);
    expect(find.text('快捷入口'), findsNothing);
    expect(find.text('久坐阈值'), findsNothing);
    expect(find.text('久站阈值'), findsNothing);
  });

  testWidgets('today posture summary uses posture sessions', (tester) async {
    await _pumpHome(
      tester,
      postureRepository: _FakePostureRepository(
        todaySessions: [
          PostureSession(
            id: 1,
            type: PostureType.sitting,
            startedAt: DateTime(2026, 6, 6, 8),
            endedAt: DateTime(2026, 6, 6, 8, 50),
            durationSeconds: 3000,
            exceededSeconds: 300,
          ),
          PostureSession(
            id: 2,
            type: PostureType.walking,
            startedAt: DateTime(2026, 6, 6, 9),
            endedAt: DateTime(2026, 6, 6, 9, 35),
            durationSeconds: 2100,
          ),
        ],
      ),
    );

    await _scrollDown(tester);
    expect(find.text('今日节奏'), findsOneWidget);
    expect(find.text('今日最长坐姿'), findsOneWidget);
    expect(find.text('今日最长走动'), findsOneWidget);
    expect(find.text('今日提醒次数'), findsOneWidget);
    expect(find.text('今日停止次数'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-posture-summary')),
        matching: find.byKey(const ValueKey('today-posture-summary-metric')),
      ),
      findsNWidgets(4),
    );
    expect(find.text('今日坐姿累计'), findsNothing);
    expect(find.text('今日站立累计'), findsNothing);
    expect(find.text('今日走动累计'), findsNothing);
    expect(find.text('今日休息累计'), findsNothing);
    expect(find.text('50 分'), findsWidgets);
    expect(find.text('1 次'), findsWidgets);
  });

  testWidgets('today core content fits a common Android viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(
      tester,
      child: const Scaffold(body: HomePage()),
      recoveryRepository: _FakeRecoveryRepository(
        profile: RecoveryProfile(
          id: 1,
          surgeryDate: DateTime.now().subtract(const Duration(days: 10)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
    );

    expect(find.textContaining('今天是术后第'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-rhythm-timer')), findsOneWidget);
    expect(find.text('我在坐'), findsWidgets);
    expect(find.text('我在走'), findsWidgets);
    expect(find.text('今日最长坐姿'), findsOneWidget);
    expect(find.text('今日最长走动'), findsOneWidget);
    expect(find.text('今日提醒次数'), findsOneWidget);
    expect(find.text('今日停止次数'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('今日停止次数')).dy,
      lessThanOrEqualTo(800),
    );
  });

  testWidgets('today summary metric cards avoid narrow viewport overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 851));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(
      tester,
      child: const Scaffold(body: HomePage()),
    );

    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollDown(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -700));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpHome(
  WidgetTester tester, {
  _FakePostureRepository? postureRepository,
  _FakeRecoveryRepository? recoveryRepository,
  _FakeNotification? notificationService,
  _FakeRehabRepository? rehabRepository,
  ValueChanged<int>? onOpenTab,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await _pumpApp(
    tester,
    child: Scaffold(body: HomePage(onOpenTab: onOpenTab)),
    postureRepository: postureRepository,
    recoveryRepository: recoveryRepository,
    notificationService: notificationService,
    rehabRepository: rehabRepository,
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required Widget child,
  _FakePostureRepository? postureRepository,
  _FakeRecoveryRepository? recoveryRepository,
  _FakeNotification? notificationService,
  _FakeRehabRepository? rehabRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postureSessionRepositoryProvider.overrideWithValue(
          postureRepository ?? _FakePostureRepository(),
        ),
        reminderSettingsRepositoryProvider.overrideWithValue(
          _FakeReminderSettingsRepository(),
        ),
        notificationServiceProvider.overrideWithValue(
          notificationService ?? _FakeNotification(),
        ),
        rehabRepositoryProvider.overrideWithValue(
          rehabRepository ?? _FakeRehabRepository(),
        ),
        recoveryRepositoryProvider.overrideWithValue(
          recoveryRepository ?? _FakeRecoveryRepository(),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

PostureSession _session(PostureType type, {required int minutesAgo}) {
  return PostureSession(
    id: 1,
    type: type,
    startedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
  );
}

class _FakePostureRepository implements PostureSessionRepository {
  _FakePostureRepository({this.openSession, this.todaySessions = const []});

  PostureSession? openSession;
  final List<PostureSession> todaySessions;

  @override
  Future<void> endCurrent({
    DateTime? now,
    int? sittingThresholdMinutes,
    int? standingThresholdMinutes,
    int? walkingThresholdMinutes,
    String endReason = 'manual_end',
    String source = 'manual',
    String? note,
  }) async {
    openSession = null;
  }

  @override
  Future<List<PostureSession>> loadAll() async => todaySessions;

  @override
  Future<PostureSession?> loadOpenSession() async => openSession;

  @override
  Future<List<PostureSession>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async =>
      todaySessions;

  @override
  Future<List<PostureSession>> loadSessionsBetween({
    required DateTime start,
    required DateTime end,
  }) async =>
      todaySessions;

  @override
  Future<List<PostureSession>> loadToday({DateTime? now}) async =>
      todaySessions;

  @override
  Future<PostureSession> switchTo({
    required PostureType type,
    DateTime? now,
    int? sittingThresholdMinutes,
    int? standingThresholdMinutes,
    int? walkingThresholdMinutes,
    String endReason = 'user_switch',
    String source = 'manual',
    String? note,
  }) async {
    openSession = PostureSession(
      id: 9,
      type: type,
      startedAt: now ?? DateTime.now(),
    );
    return openSession!;
  }
}

class _FakeReminderSettingsRepository implements ReminderSettingsRepository {
  @override
  Future<ReminderSettings> load() async => ReminderSettings.defaults;

  @override
  Future<void> save(ReminderSettings settings) async {}
}

class _FakeNotification extends NotificationService {
  _FakeNotification({
    List<bool> dueResults = const [],
    this.failScheduling = false,
    this.delayFirstSchedule = false,
  }) : _dueResults = [...dueResults];

  final List<bool> _dueResults;
  final bool failScheduling;
  final bool delayFirstSchedule;
  final scheduledPostures = <PostureType?>[];
  final duePostures = <PostureType>[];
  final dueModes = <ReminderMode>[];
  final cancelledPostures = <PostureType>[];
  final Completer<void> _firstScheduleCompleter = Completer<void>();
  var _scheduleCalls = 0;
  int initializeCalls = 0;
  int permissionRequests = 0;
  String? lastRecordedError;

  void completeFirstSchedule() {
    if (!_firstScheduleCompleter.isCompleted) {
      _firstScheduleCompleter.complete();
    }
  }

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> scheduleNextReminders({
    required bool enabled,
    required int sittingIntervalMinutes,
    required int standingIntervalMinutes,
    int walkingIntervalMinutes = 10,
    ReminderMode reminderMode = ReminderMode.soft,
    PostureType? currentPosture,
    DateTime? currentSessionStartedAt,
  }) async {
    if (failScheduling) {
      throw StateError('schedule failed');
    }
    _scheduleCalls++;
    if (delayFirstSchedule && _scheduleCalls == 1) {
      await _firstScheduleCompleter.future;
    }
    scheduledPostures.add(currentPosture);
  }

  @override
  Future<bool> showPostureDueReminder({
    required PostureType posture,
    ReminderMode reminderMode = ReminderMode.soft,
  }) async {
    duePostures.add(posture);
    dueModes.add(reminderMode);
    if (_dueResults.isEmpty) {
      return true;
    }
    return _dueResults.removeAt(0);
  }

  @override
  Future<void> cancelScheduledReminderForPosture(PostureType posture) async {
    cancelledPostures.add(posture);
  }

  @override
  void recordError(Object error) {
    lastRecordedError = error.toString();
  }
}

class _FakeRehabRepository implements RehabRepository {
  final addedLogs = <RehabLog>[];

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
    final log = RehabLog(
      id: addedLogs.length + 1,
      actionId: action.id,
      amount: amount,
      amountValue: double.tryParse(amount.trim()) ?? 0,
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
  }) async =>
      addedLogs;

  @override
  Future<List<RehabLog>> loadLogsBetween({
    required DateTime start,
    required DateTime end,
  }) async =>
      addedLogs.where((log) {
        return !log.createdAt.isBefore(start) && log.createdAt.isBefore(end);
      }).toList();

  @override
  Future<List<RehabLog>> loadToday({DateTime? now}) async => addedLogs;
}

class _FakeRecoveryRepository implements RecoveryRepository {
  _FakeRecoveryRepository({this.profile});

  final RecoveryProfile? profile;
  int savedNoteCount = 0;

  @override
  Future<RecoveryProfile?> loadProfile() async => profile;

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
  }) async {
    savedNoteCount++;
  }

  @override
  Future<void> saveProfile({
    DateTime? surgeryDate,
    String? nickname,
    String? surgeryType,
    String? mainSegment,
    String? mainGoal,
  }) async {}
}
