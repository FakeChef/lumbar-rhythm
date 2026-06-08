import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/notifications/notification_service.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';

void main() {
  test('sitting schedules only sitting reminder', () {
    final plan = buildReminderSchedulePlan(
      enabled: true,
      currentPosture: PostureType.sitting,
    );

    expect(plan.kinds, [ReminderKind.sitting]);
  });

  test('standing schedules only standing reminder', () {
    final plan = buildReminderSchedulePlan(
      enabled: true,
      currentPosture: PostureType.standing,
    );

    expect(plan.kinds, [ReminderKind.standing]);
  });

  test('walking schedules only walking reminder and resting cancels reminders',
      () {
    final walking = buildReminderSchedulePlan(
      enabled: true,
      currentPosture: PostureType.walking,
    );
    final resting = buildReminderSchedulePlan(
      enabled: true,
      currentPosture: PostureType.resting,
    );

    expect(walking.kinds, [ReminderKind.walking]);
    expect(resting.kinds, isEmpty);
  });

  test('null current posture cancels sitting and standing reminders', () {
    final plan = buildReminderSchedulePlan(
      enabled: true,
      currentPosture: null,
    );

    expect(plan.kinds, isEmpty);
  });

  test('disabled reminders cancel all posture reminders', () {
    final plan = buildReminderSchedulePlan(
      enabled: false,
      currentPosture: PostureType.sitting,
    );

    expect(plan.kinds, isEmpty);
  });
}
