import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lumbar_rhythm/core/notifications/notification_service.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/settings/domain/reminder_settings.dart';

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
      [ReminderKind.walking],
    );
  });

  test('uses separate Android notification channels for reminder modes', () {
    final soft = buildReminderNotificationDetails(
      reminderMode: ReminderMode.soft,
    ).android;
    final vibration = buildReminderNotificationDetails(
      reminderMode: ReminderMode.vibration,
    ).android;
    final alarm = buildReminderNotificationDetails(
      reminderMode: ReminderMode.alarm,
    ).android;

    expect(soft?.channelId, 'lumbar_rhythm_soft_reminders_v2');
    expect(vibration?.channelId, 'lumbar_rhythm_vibration_reminders_v2');
    expect(alarm?.channelId, 'lumbar_rhythm_alarm_reminders_v2');
  });

  test('notification details are Android-only and include gentle actions', () {
    final details = buildReminderNotificationDetails();
    final android = details.android;

    expect(details.iOS, isNull);
    expect(android, isNotNull);
    expect(
      android!.actions?.map((action) => action.id),
      containsAll(['postpone_10m', 'dismiss_once']),
    );
    expect(
      android.actions?.map((action) => action.title),
      containsAll(['10 分钟后提醒', '忽略本次']),
    );
  });

  test('notification service source does not contain Darwin branches', () {
    final source = File('lib/core/notifications/notification_service.dart')
        .readAsStringSync();

    expect(source, isNot(contains('Darwin')));
    expect(source, isNot(contains('IOSFlutterLocalNotificationsPlugin')));
  });

  test('vibration reminder does not play sound', () {
    final details = buildReminderNotificationDetails(
      reminderMode: ReminderMode.vibration,
    );
    final android = details.android;

    expect(android, isNotNull);
    expect(android!.playSound, isFalse);
    expect(android.enableVibration, isTrue);
    expect(android.vibrationPattern, isNotNull);
  });

  test('alarm reminder uses sound and vibration with high priority', () {
    final details = buildReminderNotificationDetails(
      reminderMode: ReminderMode.alarm,
    );
    final android = details.android;

    expect(android, isNotNull);
    expect(android!.importance, Importance.high);
    expect(android.priority, Priority.high);
    expect(android.playSound, isTrue);
    expect(android.enableVibration, isTrue);
    expect(android.vibrationPattern, isNotNull);
  });
}
