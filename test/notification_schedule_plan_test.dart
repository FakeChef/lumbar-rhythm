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

    expect(soft?.channelId, 'lumbar_rhythm_soft_reminders_v3');
    expect(vibration?.channelId, 'lumbar_rhythm_vibration_reminders_v3');
    expect(alarm?.channelId, 'lumbar_rhythm_alarm_reminders_v3');
    expect(soft?.importance, Importance.high);
    expect(vibration?.importance, Importance.high);
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
    final source = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Darwin')));
    expect(source, isNot(contains('IOSFlutterLocalNotificationsPlugin')));
  });

  test(
    'Android manifest declares local notification permissions and receivers',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.VIBRATE'));
      expect(
        manifest,
        contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
        ),
      );
      if (manifest.contains('android.permission.RECEIVE_BOOT_COMPLETED')) {
        expect(
          manifest,
          contains(
            'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
          ),
        );
        expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
        expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
      }
      expect(manifest, isNot(contains('android.permission.USE_EXACT_ALARM')));
      expect(
        manifest,
        isNot(contains('android.permission.SCHEDULE_EXACT_ALARM')),
      );
    },
  );

  test(
    'scheduled reminders initialize timezone database before scheduling',
    () {
      final service = File(
        'lib/core/notifications/notification_service.dart',
      ).readAsStringSync();
      final scheduleStart = service.indexOf('Future<void> _scheduleReminder');
      final scheduleEnd = service.indexOf('Future<List<int>> _readPending');
      final scheduleReminder = service.substring(scheduleStart, scheduleEnd);

      expect(
        scheduleReminder.indexOf('_ensureTimeZonesInitialized();'),
        lessThan(scheduleReminder.indexOf('_plugin.zonedSchedule')),
      );
      expect(service, contains('tz_data.initializeTimeZones();'));
    },
  );

  test(
    'notification service does not reference Android raw sound resources',
    () {
      final service = File(
        'lib/core/notifications/notification_service.dart',
      ).readAsStringSync();
      final rawSoundDirectory = Directory('android/app/src/main/res/raw');

      expect(service, isNot(contains('RawResourceAndroidNotificationSound')));
      expect(rawSoundDirectory.existsSync(), isFalse);
    },
  );

  test('notification initialization uses a drawable small icon', () {
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final icon = File(
      'android/app/src/main/res/drawable/ic_stat_notification.xml',
    );

    expect(
      service,
      contains("AndroidInitializationSettings('ic_stat_notification')"),
    );
    expect(
      service,
      isNot(contains("AndroidInitializationSettings('@mipmap/ic_launcher')")),
    );
    expect(manifest, contains('@drawable/ic_stat_notification'));
    expect(icon.existsSync(), isTrue);
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
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();

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

  test(
    'immediate reminders use direct plugin show without scheduled pending',
    () {
      final service = File(
        'lib/core/notifications/notification_service.dart',
      ).readAsStringSync();
      final showReminderNowStart = service.indexOf(
        'Future<bool> showReminderNow',
      );
      final foregroundStart = service.indexOf(
        'Future<bool> scheduleForegroundTimerTestReminder',
      );
      final showReminderNow = service.substring(
        showReminderNowStart,
        foregroundStart,
      );

      expect(showReminderNow, contains('_showNotification'));
      expect(showReminderNow, isNot(contains('zonedSchedule')));
      expect(showReminderNow, isNot(contains('pendingNotificationRequests')));
      expect(
        showReminderNow,
        isNot(contains('refreshPendingScheduledNotifications')),
      );
    },
  );

  test('foreground test uses Dart Timer before direct show', () {
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();
    final foregroundStart = service.indexOf(
      'Future<bool> scheduleForegroundTimerTestReminder',
    );
    final oneMinuteStart = service.indexOf(
      'Future<bool> scheduleOneMinuteSittingTestReminder',
    );
    final foregroundTest = service.substring(foregroundStart, oneMinuteStart);

    expect(foregroundTest, contains('Timer(delay'));
    expect(foregroundTest, contains('showReminderNow'));
    expect(foregroundTest, contains('lastForegroundTimerFiredAt'));
    expect(foregroundTest, isNot(contains('zonedSchedule')));
    expect(foregroundTest, isNot(contains('pendingNotificationRequests')));
  });

  test('scheduled notifications are documented as background fallback', () {
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();

    expect(settings, contains('主提醒路径'));
    expect(settings, contains('Android 后台定时辅助路径'));
    expect(settings, contains('系统已处理该定时提醒，但本机可能未展示'));
    expect(service, contains('系统已处理该定时提醒，但本机可能未展示'));
    expect(service, contains('Android may delay inexact reminders'));
  });

  test('scheduled reminder path requests runtime notification permission', () {
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();
    final scheduleNextStart = service.indexOf(
      'Future<void> scheduleNextReminders',
    );
    final cancelStart = service.indexOf(
      'Future<void> cancelScheduledReminders',
    );
    final scheduleNext = service.substring(scheduleNextStart, cancelStart);

    expect(scheduleNext, contains('requestPermissions()'));
    expect(
      scheduleNext.indexOf('requestPermissions()'),
      lessThan(scheduleNext.indexOf('_scheduleReminder(')),
    );
    expect(scheduleNext, contains('系统通知权限未开启'));
  });

  test('app startup defers notification setup until after the first frame', () {
    final app = File('lib/app/lumbar_rhythm_app.dart').readAsStringSync();

    expect(app, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(app, isNot(contains('Future.microtask(_initializeNotifications)')));
  });

  test('notification failures are recorded in debug state', () {
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();
    final app = File('lib/app/lumbar_rhythm_app.dart').readAsStringSync();
    final postureController = File(
      'lib/features/posture/application/posture_session_controller.dart',
    ).readAsStringSync();

    expect(service, contains('void recordError(Object error)'));
    expect(app, contains('notificationService.recordError(error)'));
    expect(postureController, contains('recordError(error)'));
  });

  test('one minute test uses a dedicated id and records pending state', () {
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();

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

  test(
    'stop recording cancels pending reminders and foreground timer can show',
    () {
      final postureController = File(
        'lib/features/posture/application/posture_session_controller.dart',
      ).readAsStringSync();
      final service = File(
        'lib/core/notifications/notification_service.dart',
      ).readAsStringSync();

      expect(postureController, contains('showPostureDueReminder'));
      expect(postureController, contains('postureReminderStatusProvider'));
      expect(postureController, contains('_foregroundReminderSessionId'));
      expect(postureController, contains('_startForegroundMonitor(session);'));
      expect(postureController, contains('await _scheduleFor(session)'));
      expect(
        postureController,
        contains('currentSessionStartedAt: session?.startedAt'),
      );
      expect(postureController, contains('_stopForegroundMonitor();'));
      expect(postureController, contains('await _scheduleFor(null)'));
      expect(service, contains('cancelScheduledReminders'));
      expect(service, contains('_foregroundTestTimer?.cancel()'));
      expect(
        service,
        isNot(contains('await _plugin.cancel(_foregroundTimerTestReminderId)')),
      );
    },
  );

  test(
    'sitting and walking foreground reminders call direct now path once',
    () {
      final postureController = File(
        'lib/features/posture/application/posture_session_controller.dart',
      ).readAsStringSync();
      final service = File(
        'lib/core/notifications/notification_service.dart',
      ).readAsStringSync();

      expect(
        postureController,
        contains('session.id == _foregroundReminderSessionId'),
      );
      expect(
        postureController,
        contains('_foregroundReminderSessionId = session.id'),
      );
      expect(postureController, contains('settings.walkingIntervalMinutes'));
      expect(postureController, contains('settings.sittingIntervalMinutes'));
      expect(postureController, contains('showPostureDueReminder'));
      expect(service, contains('showPostureDueReminder'));
      expect(service, contains('return showReminderNow'));
    },
  );

  test(
    'posture due reminders only show direct sitting and walking ids',
    () async {
      final service = _CapturingNotificationService();

      expect(
        await service.showPostureDueReminder(
          posture: PostureType.sitting,
          reminderMode: ReminderMode.vibration,
        ),
        isTrue,
      );
      expect(
        await service.showPostureDueReminder(
          posture: PostureType.walking,
          reminderMode: ReminderMode.alarm,
        ),
        isTrue,
      );
      expect(
        await service.showPostureDueReminder(posture: PostureType.standing),
        isFalse,
      );
      expect(
        await service.showPostureDueReminder(posture: PostureType.resting),
        isFalse,
      );

      expect(service.shownIds, [101, 103]);
      expect(service.shownModes, [ReminderMode.vibration, ReminderMode.alarm]);
    },
  );

  test('does not request exact alarm permission by default', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final service = File(
      'lib/core/notifications/notification_service.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();

    expect(androidManifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(androidManifest, isNot(contains('USE_EXACT_ALARM')));
    expect(service, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
    expect(settings, contains('主提醒路径'));
  });

  test('reminder diagnostics do not add medical judgment copy', () {
    final source = (File(
              'lib/core/notifications/notification_service.dart',
            ).readAsStringSync() +
            File(
              'lib/features/settings/presentation/settings_page.dart',
            ).readAsStringSync())
        .replaceAll('以上阶段说明仅用于帮助理解记录节奏，不作为医疗诊断或个人康复处方。', '');
    const forbidden = ['诊断', '治疗', '治愈', '复发判断', '医疗建议'];

    for (final word in forbidden) {
      expect(source, isNot(contains(word)));
    }
  });
}

class _CapturingNotificationService extends NotificationService {
  final shownIds = <int>[];
  final shownModes = <ReminderMode>[];

  @override
  Future<bool> showReminderNow({
    required ReminderMode mode,
    required String title,
    required String body,
    int id = 199,
    bool markAsImmediateTest = false,
  }) async {
    shownIds.add(id);
    shownModes.add(mode);
    return true;
  }
}
