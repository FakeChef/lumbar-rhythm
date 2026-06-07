import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  test('uses audible high priority Android notification details', () {
    final details = buildReminderNotificationDetails();
    final android = details.android;

    expect(android, isNotNull);
    expect(android!.channelId, 'lumbar_rhythm_reminders_v2');
    expect(android.importance, Importance.high);
    expect(android.priority, Priority.high);
    expect(android.playSound, isTrue);
    expect(android.enableVibration, isTrue);
    expect(android.vibrationPattern, isNotNull);
  });
}
