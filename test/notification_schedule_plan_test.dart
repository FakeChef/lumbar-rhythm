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
    expect(manifest, contains('com.android.alarm.permission.SET_ALARM'));
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
      contains('android.permission.SCHEDULE_EXACT_ALARM'),
    );
    expect(
        manifest, contains('user_visible_health_posture_countdown_reminder'));
  });

  test('system alarm or timer handoff is the primary posture reminder path',
      () {
    final scheduler = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/PostureAlarmScheduler.kt',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/PostureCountdownService.kt',
    ).readAsStringSync();
    final systemTimer = File(
      'lib/core/reminders/system_timer_handoff_service.dart',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/MainActivity.kt',
    ).readAsStringSync();
    final controller = File(
      'lib/features/posture/application/posture_session_controller.dart',
    ).readAsStringSync();
    final receiver = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/PostureAlarmReceiver.kt',
    ).readAsStringSync();

    expect(
        systemTimer, contains("MethodChannel('lumbar_rhythm/system_timer')"));
    expect(activity, contains('AlarmClock.ACTION_SET_TIMER'));
    expect(activity, contains('AlarmClock.ACTION_SET_ALARM'));
    expect(activity, contains('AlarmClock.EXTRA_LENGTH'));
    expect(activity, contains('AlarmClock.EXTRA_HOUR'));
    expect(activity, contains('AlarmClock.EXTRA_MINUTES'));
    expect(activity, contains('AlarmClock.EXTRA_MESSAGE'));
    expect(activity, isNot(contains('EXTRA_SKIP_UI')));
    expect(activity, contains('prefersAlarmHandoff'));
    expect(activity, contains('Build.MANUFACTURER'));
    expect(activity, contains('Build.BRAND'));
    expect(activity, contains('vivo'));
    expect(activity, contains('iqoo'));
    expect(activity, contains('system_reminder_unavailable'));
    expect(controller, contains('systemTimerHandoffServiceProvider'));
    expect(controller, contains('已交给系统提醒'));
    expect(controller, contains('无法打开系统闹钟或计时器，请手动打开系统时钟设置提醒。'));
    expect(service, contains('hasActiveSession'));
    expect(service, contains('expectedEndTimeMillis'));
    expect(service, contains('setExactAndAllowWhileIdle'));
    expect(service, contains('setAndAllowWhileIdle'));
    expect(service, contains('ACTION_SNOOZE_10'));
    expect(service, contains('ACTION_CANCEL'));
    expect(service, contains('ACTION_HANDLED'));
    expect(service, contains('canScheduleExactAlarms'));
    expect(service, contains('notification_permission_denied'));
    expect(service, isNot(contains('ACTION_SET_TIMER')));
    expect(scheduler, isNot(contains('setAlarmClock')));
    expect(receiver, contains('PostureCountdownService.handleAction'));
  });

  test('foreground service is countdown fallback and does not loop', () {
    final service = File(
      'android/app/src/main/kotlin/app/lumbarhythm/lumbar_rhythm/PostureCountdownService.kt',
    ).readAsStringSync();

    expect(service, contains('startForeground'));
    expect(service, contains('TICK_INTERVAL_MILLIS = 15_000L'));
    expect(service, contains('showDueNotification'));
    expect(service, contains('handleDue'));
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
    expect(service, contains("MethodChannel('lumbar_rhythm/reminder')"));
    expect(service, contains('PostureCountdownStartResult'));
    expect(service, contains('ReminderPermissionStatus'));
    expect(service, contains('notification_permission_denied'));
    expect(service, contains('startPostureCountdown'));
    expect(service, contains('stopPostureCountdown'));
    expect(service, contains('completePostureCountdown'));
    expect(service, contains('snoozePostureCountdown'));
    expect(service, contains('getPostureCountdownState'));
    expect(service, contains('getReminderPermissionStatus'));
    expect(service, contains('openExactAlarmSettings'));
    expect(activity, contains('startSittingReminder'));
    expect(activity, contains('startStandingReminder'));
    expect(activity, contains('cancelReminder'));
    expect(activity, contains('completeReminder'));
    expect(activity, contains('snoozeReminder'));
    expect(activity, contains('getActiveReminderSession'));
    expect(activity, contains('getReminderPermissionStatus'));
    expect(activity, contains('openExactAlarmSettings'));
  });

  test('settings diagnostics exposes non-blocking countdown chain test', () {
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();

    expect(settings, contains('_formatExactAlarmPermission'));
    expect(settings, contains('openExactAlarmSettings'));
    expect(settings, contains('scheduleTodaySittingChainTest'));
    expect(settings, contains('10 秒前台倒计时测试'));
    expect(settings, contains('30 秒前台倒计时测试'));
    expect(settings, contains('1 分钟锁屏测试'));
    expect(settings, contains('3 分钟后台测试'));
    expect(settings, contains('取消测试'));
    expect(settings, contains('重启恢复测试'));
    expect(settings, contains('真实 45 分钟验收测试'));
    expect(settings, contains('mode='));
    expect(settings, contains('code='));
    expect(settings, contains('message='));
    expect(settings, contains('dueAt='));
    expect(settings, contains('当前系统不支持直接打开该设置，请优先使用系统闹钟或计时器提醒。'));
    expect(settings, contains('准时提醒权限未开启，提醒可能延迟'));
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

  test('settings and home copy describe system alarm or timer handoff', () {
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();
    final controller = File(
      'lib/features/posture/application/posture_session_controller.dart',
    ).readAsStringSync();

    expect(settings, contains('系统闹钟或计时器提醒'));
    expect(settings, contains('会打开系统闹钟或计时器'));
    expect(settings, contains('前台倒计时仅保留为旧链路排查'));
    expect(controller, contains('已交给系统提醒'));
    expect(controller, contains('当前状态不需要系统提醒'));
    expect(controller, contains('如系统闹钟或计时器仍在运行，请在系统时钟中取消'));
    expect(settings, isNot(contains('白天节奏')));
    expect(settings, isNot(contains('自动循环提醒')));
    expect(settings, isNot(contains('全天节奏提醒')));
    expect(controller, isNot(contains('系统提醒启动失败，请检查通知权限')));
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
