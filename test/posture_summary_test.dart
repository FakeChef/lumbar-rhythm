import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_summary.dart';

void main() {
  test('summarizes posture durations and threshold counts', () {
    final now = DateTime(2026, 6, 6, 12);
    final summary = PostureSummary(
      now: now,
      sessions: [
        PostureSession(
          id: 1,
          type: PostureType.sitting,
          startedAt: DateTime(2026, 6, 6, 8),
          endedAt: DateTime(2026, 6, 6, 9),
          durationSeconds: 3600,
        ),
        PostureSession(
          id: 2,
          type: PostureType.standing,
          startedAt: DateTime(2026, 6, 6, 9),
          endedAt: DateTime(2026, 6, 6, 9, 45),
          durationSeconds: 2700,
        ),
        PostureSession(
          id: 3,
          type: PostureType.walking,
          startedAt: DateTime(2026, 6, 6, 10),
          endedAt: DateTime(2026, 6, 6, 10, 15),
          durationSeconds: 900,
        ),
      ],
    );

    expect(summary.sittingTotal, const Duration(hours: 1));
    expect(summary.standingTotal, const Duration(minutes: 45));
    expect(summary.walkingTotal, const Duration(minutes: 15));
    expect(summary.longestSitting, const Duration(hours: 1));
    expect(summary.longestStanding, const Duration(minutes: 45));
    expect(summary.longestWalking, const Duration(minutes: 15));
    expect(summary.switchCount, 2);
    expect(summary.sittingOverThresholdCount, 1);
    expect(summary.standingOverThresholdCount, 1);
  });

  test('builds recent day posture trend summaries', () {
    final now = DateTime(2026, 6, 6, 12);
    final summary = PostureSummary(
      now: now,
      sessions: [
        PostureSession(
          id: 1,
          type: PostureType.sitting,
          startedAt: DateTime(2026, 6, 5, 8),
          endedAt: DateTime(2026, 6, 5, 8, 30),
        ),
        PostureSession(
          id: 2,
          type: PostureType.resting,
          startedAt: DateTime(2026, 6, 6, 11),
          endedAt: DateTime(2026, 6, 6, 11, 20),
        ),
      ],
    );

    final days = summary.recentDaySummaries(days: 2);

    expect(days.first.day, DateTime(2026, 6, 5));
    expect(days.first.sitting, const Duration(minutes: 30));
    expect(days.last.day, DateTime(2026, 6, 6));
    expect(days.last.resting, const Duration(minutes: 20));
  });

  test('counts walking reminders and manual stops for sit-walk rhythm', () {
    final summary = PostureSummary(
      now: DateTime(2026, 6, 6, 12),
      sessions: [
        PostureSession(
          id: 1,
          type: PostureType.sitting,
          startedAt: DateTime(2026, 6, 6, 8),
          endedAt: DateTime(2026, 6, 6, 8, 50),
          exceededSeconds: 300,
          endReason: 'user_switch',
        ),
        PostureSession(
          id: 2,
          type: PostureType.walking,
          startedAt: DateTime(2026, 6, 6, 8, 50),
          endedAt: DateTime(2026, 6, 6, 9),
          exceededSeconds: 120,
          endReason: 'manual_end',
        ),
      ],
    );

    expect(summary.walkingOverThresholdCount, 1);
    expect(summary.rhythmReminderCount, 2);
    expect(summary.stopCount, 1);
  });
}
