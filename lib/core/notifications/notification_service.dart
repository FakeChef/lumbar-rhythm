import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/posture/domain/posture_session.dart';
import '../../features/settings/domain/reminder_settings.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

enum ReminderKind {
  sitting,
  standing,
}

class ReminderSchedulePlan {
  const ReminderSchedulePlan({required this.kinds});

  final List<ReminderKind> kinds;

  bool get shouldCancelOnly => kinds.isEmpty;
}

ReminderSchedulePlan buildReminderSchedulePlan({
  required bool enabled,
  required PostureType? currentPosture,
}) {
  if (!enabled || currentPosture == null) {
    return const ReminderSchedulePlan(kinds: []);
  }

  return switch (currentPosture) {
    PostureType.sitting => const ReminderSchedulePlan(
        kinds: [ReminderKind.sitting],
      ),
    PostureType.standing => const ReminderSchedulePlan(
        kinds: [ReminderKind.standing],
      ),
    PostureType.walking || PostureType.resting => const ReminderSchedulePlan(
        kinds: [],
      ),
  };
}

class NotificationService {
  static const _sittingReminderId = 101;
  static const _standingReminderId = 102;
  static const _testReminderId = 199;
  static const softChannelId = 'lumbar_rhythm_soft_reminders_v2';
  static const vibrationChannelId = 'lumbar_rhythm_vibration_reminders_v2';
  static const alarmChannelId = 'lumbar_rhythm_alarm_reminders_v2';
  static const _channelDescription = '久坐久站和休息节奏提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _timeZonesInitialized = false;
  bool _notificationsInitialized = false;

  Future<void> initialize() async {
    if (_notificationsInitialized) {
      return;
    }

    _ensureTimeZonesInitialized();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);
    _notificationsInitialized = true;
  }

  Future<bool> requestPermissions() async {
    final androidPermission = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    return androidPermission ?? true;
  }

  Future<void> scheduleNextReminders({
    required bool enabled,
    required int sittingIntervalMinutes,
    required int standingIntervalMinutes,
    ReminderMode reminderMode = ReminderMode.soft,
    PostureType? currentPosture,
  }) async {
    await initialize();
    await cancelScheduledReminders();

    final plan = buildReminderSchedulePlan(
      enabled: enabled,
      currentPosture: currentPosture,
    );

    if (plan.shouldCancelOnly) {
      return;
    }

    final permissionGranted = await requestPermissions();
    if (!permissionGranted) {
      return;
    }

    for (final kind in plan.kinds) {
      switch (kind) {
        case ReminderKind.sitting:
          await _scheduleReminder(
            id: _sittingReminderId,
            title: '该起身活动一下了',
            body: '已经接近久坐提醒间隔，建议短暂站立或走动。',
            minutesFromNow: sittingIntervalMinutes,
            reminderMode: reminderMode,
          );
        case ReminderKind.standing:
          await _scheduleReminder(
            id: _standingReminderId,
            title: '该坐下休息一下了',
            body: '已经接近久站提醒间隔，建议短暂坐下放松。',
            minutesFromNow: standingIntervalMinutes,
            reminderMode: reminderMode,
          );
      }
    }
  }

  Future<void> cancelScheduledReminders() async {
    await _plugin.cancel(_sittingReminderId);
    await _plugin.cancel(_standingReminderId);
  }

  Future<bool> showTestReminder({
    ReminderMode reminderMode = ReminderMode.soft,
  }) async {
    try {
      await initialize();

      final permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        return false;
      }

      await _plugin.show(
        _testReminderId,
        '腰椎节奏提醒测试',
        '本地通知已可用。后续提醒会按你的设置安排。',
        _notificationDetails(reminderMode),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> scheduleOneMinuteSittingTestReminder({
    ReminderMode reminderMode = ReminderMode.soft,
  }) async {
    try {
      await initialize();

      final permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        return false;
      }

      await _plugin.cancel(_sittingReminderId);
      await _scheduleReminder(
        id: _sittingReminderId,
        title: '该起身活动一下了',
        body: '这是 1 分钟测试久坐提醒，用于确认定时调度是否可用。',
        minutesFromNow: 1,
        reminderMode: reminderMode,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _scheduleReminder({
    required int id,
    required String title,
    required String body,
    required int minutesFromNow,
    required ReminderMode reminderMode,
  }) async {
    _ensureTimeZonesInitialized();

    final scheduledAt = tz.TZDateTime.now(tz.local).add(
      Duration(minutes: minutesFromNow),
    );

    // Android may delay inexact reminders to save power, especially during
    // short tests or when the device is idle. We avoid exact alarm permission
    // here and keep the reminder local-only.
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      _notificationDetails(reminderMode),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  NotificationDetails _notificationDetails(ReminderMode reminderMode) =>
      buildReminderNotificationDetails(reminderMode: reminderMode);

  void _ensureTimeZonesInitialized() {
    if (_timeZonesInitialized) {
      return;
    }

    tz_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }
}

NotificationDetails buildReminderNotificationDetails({
  ReminderMode reminderMode = ReminderMode.soft,
}) {
  // TODO: Wire these local-only actions to callbacks when a stable notification
  // action handling path is added. They should affect only the current reminder.
  const actions = [
    AndroidNotificationAction('postpone_10m', '10 分钟后提醒'),
    AndroidNotificationAction('dismiss_once', '忽略本次'),
  ];
  final android = switch (reminderMode) {
    ReminderMode.soft => const AndroidNotificationDetails(
        NotificationService.softChannelId,
        '轻柔坐站提醒',
        channelDescription: NotificationService._channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        enableVibration: false,
        actions: actions,
      ),
    ReminderMode.vibration => AndroidNotificationDetails(
        NotificationService.vibrationChannelId,
        '震动坐站提醒',
        channelDescription: NotificationService._channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 180, 120, 180]),
        actions: actions,
      ),
    ReminderMode.alarm => AndroidNotificationDetails(
        NotificationService.alarmChannelId,
        '响铃坐站提醒',
        channelDescription: NotificationService._channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 450, 180, 450]),
        actions: actions,
        // TODO: Add a short bundled reminder sound if a gentle custom asset is introduced.
      ),
  };

  return NotificationDetails(android: android);
}
