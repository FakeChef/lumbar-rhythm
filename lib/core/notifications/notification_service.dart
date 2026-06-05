import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  static const _sittingReminderId = 101;
  static const _standingReminderId = 102;
  static const _testReminderId = 199;
  static const _channelId = 'lumbar_rhythm_reminders';
  static const _channelName = '姿势提醒';
  static const _channelDescription = '久坐久站和休息节奏提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _timeZonesInitialized = false;

  Future<void> initialize() async {
    _ensureTimeZonesInitialized();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
  }

  Future<bool> requestPermissions() async {
    final androidPermission = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final iosPermission = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return (androidPermission ?? true) && (iosPermission ?? true);
  }

  Future<void> scheduleNextReminders({
    required bool enabled,
    required int sittingIntervalMinutes,
    required int standingIntervalMinutes,
  }) async {
    await cancelScheduledReminders();

    if (!enabled) {
      return;
    }

    final permissionGranted = await requestPermissions();
    if (!permissionGranted) {
      return;
    }

    await _scheduleReminder(
      id: _sittingReminderId,
      title: '该起身活动一下了',
      body: '已经接近久坐提醒间隔，建议短暂站立或走动。',
      minutesFromNow: sittingIntervalMinutes,
    );
    await _scheduleReminder(
      id: _standingReminderId,
      title: '该坐下休息一下了',
      body: '已经接近久站提醒间隔，建议短暂坐下放松。',
      minutesFromNow: standingIntervalMinutes,
    );
  }

  Future<void> cancelScheduledReminders() async {
    await _plugin.cancel(_sittingReminderId);
    await _plugin.cancel(_standingReminderId);
  }

  Future<void> showTestReminder() async {
    final permissionGranted = await requestPermissions();
    if (!permissionGranted) {
      return;
    }

    await _plugin.show(
      _testReminderId,
      '腰椎节奏提醒测试',
      '本地通知已可用。后续提醒会按你的设置安排。',
      _notificationDetails(),
    );
  }

  Future<void> _scheduleReminder({
    required int id,
    required String title,
    required String body,
    required int minutesFromNow,
  }) async {
    _ensureTimeZonesInitialized();

    final scheduledAt = tz.TZDateTime.now(tz.local).add(
      Duration(minutes: minutesFromNow),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();

    return const NotificationDetails(android: android, iOS: ios);
  }

  void _ensureTimeZonesInitialized() {
    if (_timeZonesInitialized) {
      return;
    }

    tz_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }
}
