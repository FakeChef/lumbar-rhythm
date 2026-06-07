import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumbar_rhythm/features/actions/data/rehab_repository.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/calendar/domain/calendar_day_status.dart';
import 'package:lumbar_rhythm/features/calendar/presentation/calendar_page.dart';
import 'package:lumbar_rhythm/features/milestones/data/recovery_milestone_repository.dart';
import 'package:lumbar_rhythm/features/milestones/domain/recovery_milestone.dart';
import 'package:lumbar_rhythm/features/posture/data/posture_session_repository.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/recovery/data/recovery_repository.dart';
import 'package:lumbar_rhythm/features/recovery/domain/daily_recovery_note.dart';
import 'package:lumbar_rhythm/features/recovery/domain/recovery_profile.dart';

void main() {
  testWidgets('calendar page shows month title, legend, and status dots',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final day = DateTime(2026, 6, 7);
    await _pumpCalendar(
      tester,
      rehabLogs: [
        RehabLog(
          id: 1,
          actionId: 1,
          amount: '12',
          amountValue: 12,
          unit: '分钟',
          reaction: RehabReaction.muchWorse,
          source: 'manual',
          createdAt: day.add(const Duration(hours: 10)),
        ),
      ],
      postureSessions: [
        PostureSession(
          id: 1,
          type: PostureType.sitting,
          startedAt: day.add(const Duration(hours: 8)),
          endedAt: day.add(const Duration(hours: 9)),
          exceededSeconds: 900,
        ),
      ],
    );

    expect(find.text('康复日历'), findsOneWidget);
    expect(find.text('看看这个月的恢复轨迹'), findsOneWidget);
    expect(find.byTooltip('刷新日历'), findsNothing);
    expect(find.text('2026 年 6 月'), findsOneWidget);
    expect(find.text('有康复记录'), findsOneWidget);
    expect(find.text('坐站节奏稳定'), findsOneWidget);
    expect(find.text('有超时'), findsOneWidget);
    expect(find.text('有明显加重'), findsOneWidget);
    expect(find.text('完成节点'), findsOneWidget);

    _expectDayDotColor(
      tester,
      'rehabAction',
      calendarStatusDotColor(CalendarStatusDot.rehabAction),
    );
    _expectDayDotColor(
      tester,
      'postureExceeded',
      calendarStatusDotColor(CalendarStatusDot.postureExceeded),
    );
    _expectDayDotColor(
      tester,
      'muchWorse',
      calendarStatusDotColor(CalendarStatusDot.muchWorse),
    );
  });

  testWidgets('calendar page opens day detail from a date tap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpCalendar(
      tester,
      rehabLogs: [
        RehabLog(
          id: 1,
          actionId: 1,
          amount: '12',
          amountValue: 12,
          unit: '分钟',
          reaction: RehabReaction.noChange,
          source: 'manual',
          createdAt: DateTime(2026, 6, 7, 10),
        ),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-6-7')));
    await tester.pumpAndSettle();

    expect(find.text('2026年6月7日'), findsOneWidget);
    expect(find.text('康复动作'), findsOneWidget);
  });

  testWidgets('calendar day detail shows empty state for empty day',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-6-7')));
    await tester.pumpAndSettle();

    expect(find.text('这一天还没有记录。'), findsOneWidget);
    expect(find.text('记录一点也有价值。'), findsOneWidget);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  List<RehabLog> rehabLogs = const [],
  List<PostureSession> postureSessions = const [],
  List<DailyRecoveryNote> notes = const [],
  List<RecoveryMilestone> milestones = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarMonthProvider.overrideWith((ref) => DateTime(2026, 6)),
        rehabRepositoryProvider.overrideWithValue(
          _FakeRehabRepository(rehabLogs),
        ),
        postureSessionRepositoryProvider.overrideWithValue(
          _FakePostureRepository(postureSessions),
        ),
        recoveryRepositoryProvider.overrideWithValue(
          _FakeRecoveryRepository(notes),
        ),
        recoveryMilestoneRepositoryProvider.overrideWithValue(
          _FakeMilestoneRepository(milestones),
        ),
      ],
      child: const MaterialApp(home: CalendarPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectDayDotColor(WidgetTester tester, String dotName, Color color) {
  final dot = tester.widget<DecoratedBox>(
    find.byKey(ValueKey('calendar-day-dot-$dotName')),
  );
  final decoration = dot.decoration as BoxDecoration;
  expect(decoration.color, color);
}

class _FakeRehabRepository implements RehabRepository {
  const _FakeRehabRepository(this.logs);

  final List<RehabLog> logs;

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
  Future<List<RehabLog>> loadAllLogs() async => logs;

  @override
  Future<List<RehabLog>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async =>
      logs;

  @override
  Future<List<RehabLog>> loadLogsBetween({
    required DateTime start,
    required DateTime end,
  }) async =>
      logs.where((log) {
        return !log.createdAt.isBefore(start) && log.createdAt.isBefore(end);
      }).toList();

  @override
  Future<List<RehabLog>> loadToday({DateTime? now}) async => logs;
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
  }) async =>
      sessions;

  @override
  Future<List<PostureSession>> loadSessionsBetween({
    required DateTime start,
    required DateTime end,
  }) async =>
      sessions.where((session) {
        return !session.startedAt.isBefore(start) &&
            session.startedAt.isBefore(end);
      }).toList();

  @override
  Future<List<PostureSession>> loadToday({DateTime? now}) async => sessions;

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
  const _FakeRecoveryRepository(this.notes);

  final List<DailyRecoveryNote> notes;

  @override
  Future<RecoveryProfile?> loadProfile() async => null;

  @override
  Future<DailyRecoveryNote?> loadNote(DateTime date) async => null;

  @override
  Future<List<DailyRecoveryNote>> loadNotesBetween({
    required DateTime start,
    required DateTime end,
  }) async =>
      notes;

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
  }) async {}
}

class _FakeMilestoneRepository implements RecoveryMilestoneRepository {
  const _FakeMilestoneRepository(this.milestones);

  final List<RecoveryMilestone> milestones;

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
  Future<List<RecoveryMilestone>> loadMilestones() async => milestones;

  @override
  Future<void> postpone(int id, DateTime targetDate, {String? note}) async {}
}
