import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/notifications/notification_service.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/settings/domain/reminder_settings.dart';

void main() {
  test('builds countdown plan from current posture only', () {
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
    expect(soft?.importance, Importance.high);
    expect(vibration?.importance, Importance.high);
  });

  test('notification details are Android-only without repeat actions', () {
    final details = buildReminderNotificationDetails();

    expect(details.iOS, isNull);
    expect(details.android, isNotNull);
    expect(details.android!.actions, isNull);
  });

  test('Android manifest declares foreground countdown service safely', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.VIBRATE'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE'),
    );
    expect(manifest, contains('.PostureCountdownService'));
    expect(manifest, contains('.PostureAlarmReceiver'));
    expect(manifest, contains('.PostureAlarmActivity'));
    expect(manifest, contains('android:foregroundServiceType="specialUse"'));
    expect(
        manifest, isNot(contains('android.permission.ACCESS_FINE_LOCATION')));
    expect(manifest, isNot(contains('android.permission.CAMERA')));
    expect(manifest, isNot(contains('android.permission.RECORD_AUDIO')));
    expect(manifest, isNot(contains('android.permission.BODY_SENSORS')));
    expect(manifest, isNot(contains('android.permission.USE_EXACT_ALARM')));
    expect(
      manifest,
      isNot(contains('android.permission.SCHEDULE_EXACT_ALARM')),
    );
  });

  test('alarm clock scheduler is the posture reminder wake-up path', () {
    final scheduler = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/PostureAlarmScheduler.kt',
    ).readAsStringSync();
    final receiver = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/PostureAlarmReceiver.kt',
    ).readAsStringSync();

    expect(scheduler, contains('setAlarmClock'));
    expect(scheduler, contains('cancelAlarm'));
    expect(scheduler, contains('setOngoing(true)'));
    expect(scheduler, contains('setAutoCancel(false)'));
    expect(scheduler, contains('\\u6211\\u53bb\\u4f11\\u606f\\u4e86'));
    expect(scheduler, contains('\\u5df2\\u5904\\u7406'));
    expect(receiver, contains('onAlarmDue'));
    expect(receiver, isNot(contains('startAlarm(')));
  });

  test('foreground service is countdown display only and does not loop', () {
    final service = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/PostureCountdownService.kt',
    ).readAsStringSync();

    expect(service, contains('startForeground'));
    expect(service, contains('TICK_INTERVAL_MILLIS = 15_000L'));
    expect(service, contains('reminderShown'));
    expect(service, contains('if (!state.reminderShown)'));
    expect(service, contains('markDue(this@PostureCountdownService)'));
    expect(service, isNot(contains('NotificationCompat.PRIORITY_HIGH')));
    expect(service, contains('stopSelf()'));
    expect(service, isNot(contains('BOOT_COMPLETED')));
    expect(service, isNot(contains('zonedSchedule')));
  });

  test('method channel exposes manual posture countdown methods', () {
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/MainActivity.kt',
    ).readAsStringSync();

    expect(
        service, contains("MethodChannel('lumbar_rhythm/posture_countdown')"));
    expect(service, contains("MethodChannel('lumbar_rhythm/posture_alarm')"));
    expect(service, contains('startPostureCountdown'));
    expect(service, contains('stopPostureCountdown'));
    expect(service, contains('getPostureCountdownState'));
    expect(service, contains('startPostureAlarm'));
    expect(service, contains('cancelPostureAlarm'));
    expect(service, contains('getPostureAlarmState'));
    expect(activity, contains('startPostureCountdown'));
    expect(activity, contains('stopPostureCountdown'));
    expect(activity, contains('getPostureCountdownState'));
    expect(activity, contains('startPostureAlarm'));
    expect(activity, contains('cancelPostureAlarm'));
    expect(activity, contains('getPostureAlarmState'));
  });

  test('real posture reminder path no longer schedules pending notifications',
      () {
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();
    final scheduleStart = service.indexOf('Future<bool> scheduleNextReminders');
    final scheduleEnd = service.indexOf('Future<bool> schedulePostureReminder');
    final scheduleNext = service.substring(scheduleStart, scheduleEnd);

    expect(scheduleNext, contains('手动倒计时模式不安排后台定时提醒'));
    expect(scheduleNext, isNot(contains('_scheduleReminder(')));
    expect(scheduleNext, isNot(contains('zonedSchedule')));
  });

  test('settings and home copy describe manual countdown only', () {
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();
    final controller = File(
      'lib/features/posture/application/posture_session_controller.dart',
    ).readAsStringSync();

    expect(settings, contains('手动倒计时'));
    expect(settings, contains('到点提醒一次'));
    expect(controller, contains('久坐倒计时中'));
    expect(controller, contains('久站倒计时中'));
    expect(controller, contains('当前状态不需要久坐/久站倒计时'));
    expect(settings, isNot(contains('白天节奏')));
    expect(settings, isNot(contains('自动循环提醒')));
    expect(settings, isNot(contains('全天节奏提醒')));
  });

  test('diagnostic UI is simplified for regular users', () {
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();

    expect(settings, contains('检查并请求通知权限'));
    expect(settings, contains('发送立即测试提醒'));
    expect(settings, contains('打开系统通知设置'));
    expect(settings, isNot(contains('foregroundWatcherActive')));
    expect(settings, isNot(contains('lastPostureReminderTriggeredBy')));
    expect(settings, isNot(contains('查看待触发提醒')));
    expect(settings, isNot(contains('精确提醒状态')));
  });
}
