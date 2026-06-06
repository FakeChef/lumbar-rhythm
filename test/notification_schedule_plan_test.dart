import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/notifications/notification_service.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';

void main() {
  test('builds notification plan from current posture only', () {
    expect(
      buildReminderSchedulePlan(
        enabled: true,
        currentPosture: PostureType.sitting,
      ).kinds,
      [ReminderKind.sitting],
    );
    expect(
      buildReminderSchedulePlan(
        enabled: true,
        currentPosture: PostureType.standing,
      ).kinds,
      [ReminderKind.standing],
    );
    expect(
      buildReminderSchedulePlan(
        enabled: true,
        currentPosture: PostureType.walking,
      ).kinds,
      isEmpty,
    );
  });
}
