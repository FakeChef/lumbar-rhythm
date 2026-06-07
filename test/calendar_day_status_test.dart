import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/calendar/domain/calendar_day_status.dart';
import 'package:lumbar_rhythm/features/milestones/domain/recovery_milestone.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/recovery/domain/daily_recovery_note.dart';
import 'package:lumbar_rhythm/features/recovery/domain/recovery_profile.dart';

void main() {
  final day = DateTime(2026, 6, 7);
  const actions = actionLibrary;

  test('daily recovery note counts as a record without adding status dot', () {
    final status = CalendarDayStatus(
      date: day,
      actions: actions,
      rehabLogs: const [],
      postureSessions: const [],
      note: _note(day),
    );

    expect(status.hasDailyStatus, isTrue);
    expect(status.hasAnyRecord, isTrue);
    expect(status.dots, isEmpty);
  });

  test('shows a blue rehab dot when rehab logs exist', () {
    final status = CalendarDayStatus(
      date: day,
      actions: actions,
      rehabLogs: [_log(day, reaction: RehabReaction.noChange)],
      postureSessions: const [],
    );

    expect(status.hasRehabAction, isTrue);
    expect(status.dots, contains(CalendarStatusDot.rehabAction));
  });

  test('shows an orange dot when sitting or standing exceeds threshold', () {
    final status = CalendarDayStatus(
      date: day,
      actions: actions,
      rehabLogs: const [],
      postureSessions: [
        PostureSession(
          id: 1,
          type: PostureType.sitting,
          startedAt: DateTime(2026, 6, 7, 8),
          endedAt: DateTime(2026, 6, 7, 9),
          durationSeconds: 3600,
          thresholdSeconds: 2700,
          exceededSeconds: 900,
        ),
      ],
    );

    expect(status.hasPostureExceeded, isTrue);
    expect(status.dots, contains(CalendarStatusDot.postureExceeded));
  });

  test('shows a red dot when a rehab log is much worse', () {
    final status = CalendarDayStatus(
      date: day,
      actions: actions,
      rehabLogs: [_log(day, reaction: RehabReaction.muchWorse)],
      postureSessions: const [],
    );

    expect(status.hasMuchWorse, isTrue);
    expect(status.dots, contains(CalendarStatusDot.muchWorse));
  });

  test('shows a purple dot when a milestone is completed that day', () {
    final status = CalendarDayStatus(
      date: day,
      actions: actions,
      rehabLogs: const [],
      postureSessions: const [],
      milestones: [
        RecoveryMilestone(
          id: 1,
          title: '第一周康复日志',
          category: '回顾',
          status: 'completed',
          isBuiltin: true,
          sortOrder: 1,
          completedAt: DateTime(2026, 6, 7, 10),
        ),
      ],
    );

    expect(status.hasCompletedMilestone, isTrue);
    expect(status.dots, contains(CalendarStatusDot.milestoneCompleted));
  });

  test('limits calendar dots to three per day and calculates post surgery day',
      () {
    final status = CalendarDayStatus(
      date: day,
      actions: actions,
      rehabLogs: [_log(day, reaction: RehabReaction.muchWorse)],
      postureSessions: [
        PostureSession(
          id: 1,
          type: PostureType.standing,
          startedAt: DateTime(2026, 6, 7, 8),
          endedAt: DateTime(2026, 6, 7, 9),
          durationSeconds: 3600,
          thresholdSeconds: 1800,
          exceededSeconds: 1800,
        ),
      ],
      note: _note(day),
      profile: RecoveryProfile(
        id: 1,
        surgeryDate: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      ),
      milestones: [
        RecoveryMilestone(
          id: 1,
          title: '第一周康复日志',
          category: '回顾',
          status: 'completed',
          isBuiltin: true,
          sortOrder: 1,
          completedAt: DateTime(2026, 6, 7, 10),
        ),
      ],
    );

    expect(status.dots, hasLength(3));
    expect(status.dots.first, CalendarStatusDot.muchWorse);
    expect(status.postSurgeryDay, 7);
  });
}

DailyRecoveryNote _note(DateTime day) {
  return DailyRecoveryNote(
    date: day,
    overallFeeling: OverallFeeling.same,
    backPainScore: 2,
    legSymptomScore: 1,
    fatigueScore: 3,
    tags: const ['疲劳'],
    note: '今天平稳',
    createdAt: day,
    updatedAt: day,
  );
}

RehabLog _log(DateTime day, {required RehabReaction reaction}) {
  return RehabLog(
    id: 1,
    actionId: 1,
    amount: '12',
    amountValue: 12,
    unit: '分钟',
    reaction: reaction,
    source: 'manual',
    symptomTags: const ['腰酸'],
    createdAt: day.add(const Duration(hours: 9)),
  );
}
