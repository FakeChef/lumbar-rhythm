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

  test('reminder debug state records scheduled notification metadata', () {
    final dueAt = DateTime(2026, 6, 7, 14, 32);
    final state = ReminderDebugState(
      lastLocalScheduleRequestedAt: DateTime(2026, 6, 7, 14, 31),
      lastLocalScheduleDueAt: dueAt,
      lastNotificationId: 201,
      lastReminderMode: ReminderMode.alarm,
      lastChannelId: NotificationService.alarmChannelId,
      pendingNotificationCount: 1,
      pendingNotificationIds: const [201],
    );

    expect(state.lastLocalScheduleDueAt, dueAt);
    expect(state.lastNotificationId, 201);
    expect(state.lastChannelId, NotificationService.alarmChannelId);
    expect(state.pendingNotificationCount, 1);
    expect(state.pendingNotificationIds, [201]);
  });

  test('notification diagnostic source exposes four verification layers', () {
    final settings = File('lib/features/settings/presentation/settings_page.dart')
        .readAsStringSync();
    final service = File('lib/core/notifications/notification_service.dart')
        .readAsStringSync();

    expect(settings, contains('立即测试提醒'));
    expect(settings, contains('10 秒前台测试'));
    expect(settings, contains('1 分钟定时测试：inexactAllowWhileIdle'));
    expect(settings, contains('1 分钟定时测试：exactAllowWhileIdle'));
    expect(settings, contains('1 分钟定时测试：alarmClock'));
    expect(settings, contains('查看待触发提醒'));
    expect(settings, contains('showReminderNow'));
    expect(service, contains('showTestReminder'));
    expect(service, contains('showReminderNow'));
    expect(service, contains('scheduleForegroundTimerTestReminder'));
    expect(service, contains('scheduleOneMinuteSittingTestReminder'));
    expect(service, contains('pendingNotificationRequests'));
  });

  test('immediate reminders use direct plugin show without scheduled pending',
      () {
    final service = File('lib/core/notifications/notification_service.dart')
        .readAsStringSync();
    final showReminderNowStart = service.indexOf('Future<bool> showReminderNow');
    final foregroundStart =
        service.indexOf('Future<bool> scheduleForegroundTimerTestReminder');
    final showReminderNow = service.substring(
      showReminderNowStart,
      foregroundStart,
    );

    expect(showReminderNow, contains('_showNotification'));
    expect(showReminderNow, contains('_notificationDetails'));
    expect(showReminderNow, isNot(contains('zonedSchedule')));
    expect(showReminderNow, isNot(contains('pendingNotificationRequests')));
    expect(showReminderNow, isNot(contains('refreshPendingScheduledNotifications')));
  });

  test('foreground test uses Dart Timer before direct show', () {
    final service = File('lib/core/notifications/notification_service.dart')
        .readAsStringSync();
    final foregroundStart =
        service.indexOf('Future<bool> scheduleForegroundTimerTestReminder');
    final oneMinuteStart =
        service.indexOf('Future<bool> scheduleOneMinuteSittingTestReminder');
    final foregroundTest = service.substring(
      foregroundStart,
      oneMinuteStart,
    );

    expect(foregroundTest, contains('Timer(delay'));
    expect(foregroundTest, contains('showReminderNow'));
    expect(foregroundTest, contains('lastForegroundTimerFiredAt'));
    expect(foregroundTest, isNot(contains('zonedSchedule')));
    expect(foregroundTest, isNot(contains('pendingNotificationRequests')));
  });

  test('scheduled notifications are documented as background fallback', () {
    final settings = File('lib/features/settings/presentation/settings_page.dart')
        .readAsStringSync();
    final service = File('lib/core/notifications/notification_service.dart')
        .readAsStringSync();

    expect(settings, contains('主提醒路径'));
    expect(settings, contains('Android 后台定时辅助路径'));
    expect(settings, contains('系统已处理该定时提醒，但本机可能未展示'));
    expect(service, contains('系统已处理该定时提醒，但本机可能未展示'));
    expect(service, contains('Android may delay inexact reminders'));
  });

  test('one minute test uses a dedicated id and records pending state', () {
    final service = File('lib/core/notifications/notification_service.dart')
        .readAsStringSync();

    expect(service, contains('_oneMinuteSittingTestReminderId = 201'));
    expect(service, contains('ReminderScheduleDiagnosticMode'));
    expect(service, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
    expect(service, contains('AndroidScheduleMode.exactAllowWhileIdle'));
    expect(service, contains('AndroidScheduleMode.alarmClock'));
    expect(service, contains('lastLocalScheduleDueAt'));
    expect(service, contains('lastNotificationId: id'));
    expect(service, contains('lastChannelId: channelIdForReminderMode'));
    expect(service, contains('refreshPendingScheduledNotifications'));
  });

  test('stop recording cancels pending reminders and foreground timer can show',
      () {
    final postureController = File(
      'lib/features/posture/application/posture_session_controller.dart',
    ).readAsStringSync();
    final service = File('lib/core/notifications/notification_service.dart')
        .readAsStringSync();

    expect(postureController, contains('showPostureDueReminder'));
    expect(postureController, contains('postureReminderStatusProvider'));
    expect(postureController, contains('_foregroundReminderSessionId'));
    expect(postureController, contains('_startForegroundMonitor(session);'));
    expect(postureController, contains('unawaited(_scheduleFor(session.type))'));
    expect(postureController, contains('_stopForegroundMonitor();'));
    expect(postureController, contains('unawaited(_scheduleFor(null))'));
    expect(service, contains('cancelScheduledReminders'));
    expect(service, contains('_foregroundTestTimer?.cancel()'));
    expect(service, isNot(contains('await _plugin.cancel(_foregroundTimerTestReminderId)')));
  });

  test('sitting and walking foreground reminders call direct now path once', () {
    final postureController = File(
      'lib/features/posture/application/posture_session_controller.dart',
    ).readAsStringSync();
    final service = File('lib/core/notifications/notification_service.dart')
        .readAsStringSync();

    expect(postureController, contains('session.id == _foregroundReminderSessionId'));
    expect(postureController, contains('_foregroundReminderSessionId = session.id'));
    expect(postureController, contains('settings.walkingIntervalMinutes'));
    expect(postureController, contains('settings.sittingIntervalMinutes'));
    expect(postureController, contains('showPostureDueReminder'));
    expect(service, contains('showPostureDueReminder'));
    expect(service, contains('return showReminderNow'));
  });

  test('does not request exact alarm permission by default', () {
    final androidManifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(androidManifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(androidManifest, isNot(contains('USE_EXACT_ALARM')));
  });

  test('reminder diagnostics do not add medical judgment copy', () {
    final source = File('lib/core/notifications/notification_service.dart')
            .readAsStringSync() +
        File('lib/features/settings/presentation/settings_page.dart')
            .readAsStringSync();
    const forbidden = [
      '诊断',
      '治疗',
      '治愈',
      '复发判断',
      '医疗建议',
    ];

    for (final word in forbidden) {
      expect(source, isNot(contains(word)));
    }
  });
}
