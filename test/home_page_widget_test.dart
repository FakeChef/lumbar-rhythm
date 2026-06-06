import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/notifications/notification_service.dart';
import 'package:lumbar_rhythm/features/actions/data/rehab_repository.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/home/presentation/home_page.dart';
import 'package:lumbar_rhythm/features/posture/data/posture_session_repository.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/recovery/data/recovery_repository.dart';
import 'package:lumbar_rhythm/features/recovery/domain/daily_recovery_note.dart';
import 'package:lumbar_rhythm/features/recovery/domain/recovery_profile.dart';
import 'package:lumbar_rhythm/features/settings/data/reminder_settings_repository.dart';
import 'package:lumbar_rhythm/features/settings/domain/reminder_settings.dart';

void main() {
  testWidgets('shows sitting timer normal state', (tester) async {
    await _pumpHome(
      tester,
      postureRepository: _FakePostureRepository(
        openSession: _session(PostureType.sitting, minutesAgo: 10),
      ),
    );

    expect(find.text('坐站节奏'), findsOneWidget);
    expect(find.text('当前姿势：我在坐'), findsOneWidget);
    expect(find.text('正常'), findsWidgets);
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
        openSession: _session(PostureType.standing, minutesAgo: 40),
      ),
    );
    expect(find.text('已超时'), findsOneWidget);
  });

  testWidgets('shows walking and resting states', (tester) async {
    await _pumpHome(
      tester,
      postureRepository: _FakePostureRepository(
        openSession: _session(PostureType.walking, minutesAgo: 60),
      ),
    );
    expect(find.text('走动中'), findsWidgets);

    await _pumpHome(
      tester,
      postureRepository: _FakePostureRepository(
        openSession: _session(PostureType.resting, minutesAgo: 60),
      ),
    );
    expect(find.text('休息中'), findsWidgets);
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
            type: PostureType.standing,
            startedAt: DateTime(2026, 6, 6, 9),
            endedAt: DateTime(2026, 6, 6, 9, 35),
            durationSeconds: 2100,
            exceededSeconds: 300,
          ),
        ],
      ),
    );

    await _scrollDown(tester);
    expect(find.text('今日坐站摘要'), findsOneWidget);
    expect(find.text('50 分'), findsWidgets);
    expect(find.text('35 分'), findsWidgets);
    expect(find.text('1 / 1 次'), findsOneWidget);
  });

  testWidgets('daily note dialog saves quickly', (tester) async {
    final recoveryRepository = _FakeRecoveryRepository();
    await _pumpHome(tester, recoveryRepository: recoveryRepository);

    await tester.tap(find.text('记录今日状态').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(recoveryRepository.savedNoteCount, 1);
  });

  testWidgets('quick entries call tab callbacks', (tester) async {
    final openedTabs = <int>[];
    await _pumpHome(tester, onOpenTab: openedTabs.add);

    await tester.tap(find.text('记录康复动作').last);
    await tester.pump();
    await tester.tap(find.text('查看康复报告').last);
    await tester.pump();
    await tester.tap(find.text('设置提醒').last);
    await tester.pump();

    expect(openedTabs, [2, 3, 4]);
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
  ValueChanged<int>? onOpenTab,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postureSessionRepositoryProvider.overrideWithValue(
          postureRepository ?? _FakePostureRepository(),
        ),
        reminderSettingsRepositoryProvider.overrideWithValue(
          _FakeReminderSettingsRepository(),
        ),
        notificationServiceProvider.overrideWithValue(_FakeNotification()),
        rehabRepositoryProvider.overrideWithValue(_FakeRehabRepository()),
        recoveryRepositoryProvider.overrideWithValue(
          recoveryRepository ?? _FakeRecoveryRepository(),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: HomePage(onOpenTab: onOpenTab))),
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
  Future<List<PostureSession>> loadToday({DateTime? now}) async =>
      todaySessions;

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
  @override
  Future<void> scheduleNextReminders({
    required bool enabled,
    required int sittingIntervalMinutes,
    required int standingIntervalMinutes,
    PostureType? currentPosture,
  }) async {}
}

class _FakeRehabRepository implements RehabRepository {
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
    throw UnimplementedError();
  }

  @override
  Future<List<RehabAction>> loadActions() async => actionLibrary;

  @override
  Future<List<RehabLog>> loadAllLogs() async => const [];

  @override
  Future<List<RehabLog>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async =>
      const [];

  @override
  Future<List<RehabLog>> loadToday({DateTime? now}) async => const [];
}

class _FakeRecoveryRepository implements RecoveryRepository {
  int savedNoteCount = 0;

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
  }) async {
    savedNoteCount++;
  }

  @override
  Future<void> saveProfile({
    DateTime? surgeryDate,
    String? surgeryType,
    String? mainSegment,
    String? mainGoal,
  }) async {}
}
