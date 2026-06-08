import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/posture/domain/posture_session.dart';
import '../../features/settings/domain/reminder_settings.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    onDebugStateChanged: (state) {
      ref.read(reminderDebugStateProvider.notifier).state = state;
    },
  );
});

final reminderDebugStateProvider = StateProvider<ReminderDebugState>((ref) {
  return const ReminderDebugState();
});

enum ReminderKind {
  sitting,
  standing,
  walking,
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
    PostureType.walking => const ReminderSchedulePlan(
        kinds: [ReminderKind.walking],
      ),
    PostureType.resting => const ReminderSchedulePlan(
        kinds: [],
      ),
  };
}

class ReminderDebugState {
  const ReminderDebugState({
    this.lastImmediateTestAt,
    this.lastForegroundTimerScheduledAt,
    this.lastForegroundTimerDueAt,
    this.lastLocalScheduleRequestedAt,
    this.lastLocalScheduleDueAt,
    this.lastNotificationId,
    this.lastReminderMode,
    this.lastChannelId,
    this.lastErrorMessage,
    this.pendingNotificationCount,
    this.pendingNotificationIds = const [],
    this.scheduledPendingBefore,
    this.scheduledPendingAfter,
    this.lastForegroundTimerFiredAt,
    this.lastImmediateShownAt,
    this.lastScheduledModeUsed,
    this.lastScheduleModeResult,
  });

  final DateTime? lastImmediateTestAt;
  final DateTime? lastForegroundTimerScheduledAt;
  final DateTime? lastForegroundTimerDueAt;
  final DateTime? lastLocalScheduleRequestedAt;
  final DateTime? lastLocalScheduleDueAt;
  final int? lastNotificationId;
  final ReminderMode? lastReminderMode;
  final String? lastChannelId;
  final String? lastErrorMessage;
  final int? pendingNotificationCount;
  final List<int> pendingNotificationIds;
  final int? scheduledPendingBefore;
  final int? scheduledPendingAfter;
  final DateTime? lastForegroundTimerFiredAt;
  final DateTime? lastImmediateShownAt;
  final String? lastScheduledModeUsed;
  final String? lastScheduleModeResult;

  ReminderDebugState copyWith({
    DateTime? lastImmediateTestAt,
    DateTime? lastForegroundTimerScheduledAt,
    DateTime? lastForegroundTimerDueAt,
    DateTime? lastLocalScheduleRequestedAt,
    DateTime? lastLocalScheduleDueAt,
    int? lastNotificationId,
    ReminderMode? lastReminderMode,
    String? lastChannelId,
    String? lastErrorMessage,
    int? pendingNotificationCount,
    List<int>? pendingNotificationIds,
    int? scheduledPendingBefore,
    int? scheduledPendingAfter,
    DateTime? lastForegroundTimerFiredAt,
    DateTime? lastImmediateShownAt,
    String? lastScheduledModeUsed,
    String? lastScheduleModeResult,
  }) {
    return ReminderDebugState(
      lastImmediateTestAt: lastImmediateTestAt ?? this.lastImmediateTestAt,
      lastForegroundTimerScheduledAt:
          lastForegroundTimerScheduledAt ?? this.lastForegroundTimerScheduledAt,
      lastForegroundTimerDueAt:
          lastForegroundTimerDueAt ?? this.lastForegroundTimerDueAt,
      lastLocalScheduleRequestedAt:
          lastLocalScheduleRequestedAt ?? this.lastLocalScheduleRequestedAt,
      lastLocalScheduleDueAt:
          lastLocalScheduleDueAt ?? this.lastLocalScheduleDueAt,
      lastNotificationId: lastNotificationId ?? this.lastNotificationId,
      lastReminderMode: lastReminderMode ?? this.lastReminderMode,
      lastChannelId: lastChannelId ?? this.lastChannelId,
      lastErrorMessage: lastErrorMessage,
      pendingNotificationCount:
          pendingNotificationCount ?? this.pendingNotificationCount,
      pendingNotificationIds:
          pendingNotificationIds ?? this.pendingNotificationIds,
      scheduledPendingBefore:
          scheduledPendingBefore ?? this.scheduledPendingBefore,
      scheduledPendingAfter:
          scheduledPendingAfter ?? this.scheduledPendingAfter,
      lastForegroundTimerFiredAt:
          lastForegroundTimerFiredAt ?? this.lastForegroundTimerFiredAt,
      lastImmediateShownAt: lastImmediateShownAt ?? this.lastImmediateShownAt,
      lastScheduledModeUsed:
          lastScheduledModeUsed ?? this.lastScheduledModeUsed,
      lastScheduleModeResult:
          lastScheduleModeResult ?? this.lastScheduleModeResult,
    );
  }
}

enum ReminderScheduleDiagnosticMode {
  inexactAllowWhileIdle,
  exactAllowWhileIdle,
  alarmClock,
}

extension ReminderScheduleDiagnosticModeLabel
    on ReminderScheduleDiagnosticMode {
  String get label {
    return switch (this) {
      ReminderScheduleDiagnosticMode.inexactAllowWhileIdle =>
        'inexactAllowWhileIdle',
      ReminderScheduleDiagnosticMode.exactAllowWhileIdle =>
        'exactAllowWhileIdle',
      ReminderScheduleDiagnosticMode.alarmClock => 'alarmClock',
    };
  }

  AndroidScheduleMode get androidScheduleMode {
    return switch (this) {
      ReminderScheduleDiagnosticMode.inexactAllowWhileIdle =>
        AndroidScheduleMode.inexactAllowWhileIdle,
      ReminderScheduleDiagnosticMode.exactAllowWhileIdle =>
        AndroidScheduleMode.exactAllowWhileIdle,
      ReminderScheduleDiagnosticMode.alarmClock =>
        AndroidScheduleMode.alarmClock,
    };
  }
}

class NotificationService {
  static const _sittingReminderId = 101;
  static const _standingReminderId = 102;
  static const _walkingReminderId = 103;
  static const _testReminderId = 199;
  static const _foregroundTimerTestReminderId = 198;
  static const _oneMinuteSittingTestReminderId = 201;
  static const softChannelId = 'lumbar_rhythm_soft_reminders_v2';
  static const vibrationChannelId = 'lumbar_rhythm_vibration_reminders_v2';
  static const alarmChannelId = 'lumbar_rhythm_alarm_reminders_v2';
  static const _channelDescription = '久坐久站和休息节奏提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final void Function(ReminderDebugState state)? _onDebugStateChanged;

  bool _timeZonesInitialized = false;
  bool _notificationsInitialized = false;
  Timer? _foregroundTestTimer;
  ReminderDebugState _debugState = const ReminderDebugState();

  NotificationService({
    void Function(ReminderDebugState state)? onDebugStateChanged,
  }) : _onDebugStateChanged = onDebugStateChanged;

  ReminderDebugState get debugState => _debugState;

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
    int walkingIntervalMinutes = 10,
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
      _updateDebug(
        _debugState.copyWith(lastErrorMessage: '系统通知权限未开启。'),
      );
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
        case ReminderKind.walking:
          await _scheduleReminder(
            id: _walkingReminderId,
            title: '走动时间到了',
            body: '这一段走动已经完成，可以坐下休息一下。',
            minutesFromNow: walkingIntervalMinutes,
            reminderMode: reminderMode,
          );
      }
    }
  }

  Future<void> cancelScheduledReminders() async {
    await _plugin.cancel(_sittingReminderId);
    await _plugin.cancel(_standingReminderId);
    await _plugin.cancel(_walkingReminderId);
    await _plugin.cancel(_oneMinuteSittingTestReminderId);
    await refreshPendingScheduledNotifications();
  }

  Future<void> cancelScheduledReminderForPosture(PostureType posture) async {
    final id = switch (posture) {
      PostureType.sitting => _sittingReminderId,
      PostureType.standing => _standingReminderId,
      PostureType.walking => _walkingReminderId,
      PostureType.resting => null,
    };
    if (id == null) {
      return;
    }
    await _plugin.cancel(id);
    await refreshPendingScheduledNotifications();
  }

  Future<bool> showPostureDueReminder({
    required PostureType posture,
    ReminderMode reminderMode = ReminderMode.soft,
  }) async {
    return switch (posture) {
      PostureType.sitting => showReminderNow(
          mode: reminderMode,
          title: '该起身活动一下了',
          body: '已经到久坐提醒时间，建议起身走一走。',
          id: _sittingReminderId,
        ),
      PostureType.walking => showReminderNow(
          mode: reminderMode,
          title: '走动时间到了',
          body: '这一段走动已经完成，可以坐下休息一下。',
          id: _walkingReminderId,
        ),
      PostureType.standing || PostureType.resting => false,
    };
  }

  Future<bool> showTestReminder({
    ReminderMode reminderMode = ReminderMode.soft,
  }) async {
    return showReminderNow(
      mode: reminderMode,
      title: '腰椎节奏提醒测试',
      body: '本地通知已可用。后续提醒会按你的设置安排。',
      id: _testReminderId,
      markAsImmediateTest: true,
    );
  }

  Future<bool> showReminderNow({
    required ReminderMode mode,
    required String title,
    required String body,
    int id = _testReminderId,
    bool markAsImmediateTest = false,
  }) async {
    try {
      await initialize();

      final permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        _updateDebug(
          _debugState.copyWith(lastErrorMessage: '系统通知权限未开启。'),
        );
        return false;
      }

      await _showNotification(
        id: id,
        title: title,
        body: body,
        reminderMode: mode,
      );
      final now = DateTime.now();
      _updateDebug(
        _debugState.copyWith(
          lastImmediateTestAt: markAsImmediateTest ? now : null,
          lastImmediateShownAt: now,
          lastNotificationId: id,
          lastReminderMode: mode,
          lastChannelId: channelIdForReminderMode(mode),
          lastErrorMessage: null,
        ),
      );
      return true;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return false;
    }
  }

  Future<bool> scheduleForegroundTimerTestReminder({
    ReminderMode reminderMode = ReminderMode.soft,
    Duration delay = const Duration(seconds: 10),
    void Function(bool shown)? onFired,
  }) async {
    try {
      await initialize();
      final permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        return false;
      }

      _foregroundTestTimer?.cancel();
      final scheduledAt = DateTime.now();
      final dueAt = scheduledAt.add(delay);
      _updateDebug(
        _debugState.copyWith(
          lastForegroundTimerScheduledAt: scheduledAt,
          lastForegroundTimerDueAt: dueAt,
          lastNotificationId: _foregroundTimerTestReminderId,
          lastReminderMode: reminderMode,
          lastChannelId: channelIdForReminderMode(reminderMode),
          lastErrorMessage: null,
        ),
      );
      _foregroundTestTimer = Timer(delay, () {
        unawaited(
          showReminderNow(
            mode: reminderMode,
            id: _foregroundTimerTestReminderId,
            title: '腰椎节奏前台测试',
            body: '10 秒前台测试提醒已触发。',
          ).then((shown) {
            onFired?.call(shown);
            if (!shown) {
              return;
            }
            _updateDebug(
              _debugState.copyWith(
                lastForegroundTimerFiredAt: DateTime.now(),
                lastNotificationId: _foregroundTimerTestReminderId,
                lastReminderMode: reminderMode,
                lastChannelId: channelIdForReminderMode(reminderMode),
                lastErrorMessage: null,
              ),
            );
          }).catchError((Object error) {
            _updateDebug(
              _debugState.copyWith(lastErrorMessage: error.toString()),
            );
          }),
        );
      });
      return true;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return false;
    }
  }

  Future<bool> scheduleOneMinuteSittingTestReminder({
    ReminderMode reminderMode = ReminderMode.soft,
    ReminderScheduleDiagnosticMode diagnosticMode =
        ReminderScheduleDiagnosticMode.inexactAllowWhileIdle,
  }) async {
    try {
      await initialize();

      final permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        return false;
      }

      final pendingBefore = await _readPendingNotificationIds();
      await _plugin.cancel(_oneMinuteSittingTestReminderId);
      await _scheduleReminder(
        id: _oneMinuteSittingTestReminderId,
        title: '该起身活动一下了',
        body: '这是 1 分钟测试久坐提醒，用于确认定时调度是否可用。',
        minutesFromNow: 1,
        reminderMode: reminderMode,
        androidScheduleMode: diagnosticMode.androidScheduleMode,
        scheduleModeLabel: diagnosticMode.label,
      );
      final pendingAfter = await _readPendingNotificationIds();
      final containsTestId =
          pendingAfter.contains(_oneMinuteSittingTestReminderId);
      _updateDebug(
        _debugState.copyWith(
          pendingNotificationCount: pendingAfter.length,
          pendingNotificationIds: pendingAfter,
          scheduledPendingBefore: pendingBefore.length,
          scheduledPendingAfter: pendingAfter.length,
          lastScheduleModeResult:
              containsTestId ? '已安排，等待系统触发。' : '已请求安排，但 pending 列表未确认该提醒。',
          lastErrorMessage: null,
        ),
      );
      return true;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return false;
    }
  }

  Future<ReminderDebugState> refreshPendingScheduledNotifications() async {
    try {
      await initialize();
      final pending = await _plugin.pendingNotificationRequests();
      final ids = pending.map((request) => request.id).toList()..sort();
      final scheduledId = _debugState.lastNotificationId;
      final dueAt = _debugState.lastLocalScheduleDueAt;
      final systemMayHaveHandled = scheduledId != null &&
          dueAt != null &&
          DateTime.now().isAfter(dueAt) &&
          !ids.contains(scheduledId);
      _updateDebug(
        _debugState.copyWith(
          pendingNotificationCount: ids.length,
          pendingNotificationIds: ids,
          scheduledPendingAfter: ids.length,
          lastScheduleModeResult: systemMayHaveHandled
              ? '系统已处理该定时提醒，但本机可能未展示。建议以前台提醒为主。'
              : _debugState.lastScheduleModeResult,
          lastErrorMessage: null,
        ),
      );
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
    }
    return _debugState;
  }

  Future<void> _scheduleReminder({
    required int id,
    required String title,
    required String body,
    required int minutesFromNow,
    required ReminderMode reminderMode,
    AndroidScheduleMode androidScheduleMode =
        AndroidScheduleMode.inexactAllowWhileIdle,
    String scheduleModeLabel = 'inexactAllowWhileIdle',
  }) async {
    _ensureTimeZonesInitialized();

    final requestedAt = DateTime.now();
    var scheduledAt = tz.TZDateTime.now(tz.local).add(
      Duration(minutes: minutesFromNow),
    );
    final minimumDueAt = tz.TZDateTime.now(tz.local).add(
      const Duration(seconds: 5),
    );
    if (!scheduledAt.isAfter(minimumDueAt)) {
      scheduledAt = minimumDueAt;
    }
    _updateDebug(
      _debugState.copyWith(
        lastLocalScheduleRequestedAt: requestedAt,
        lastLocalScheduleDueAt: scheduledAt,
        lastNotificationId: id,
        lastReminderMode: reminderMode,
        lastChannelId: channelIdForReminderMode(reminderMode),
        lastScheduledModeUsed: scheduleModeLabel,
        lastScheduleModeResult: '已请求安排，等待 pending 确认。',
        lastErrorMessage: null,
      ),
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
      androidScheduleMode: androidScheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<List<int>> _readPendingNotificationIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toList()..sort();
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required ReminderMode reminderMode,
  }) {
    return _plugin.show(
      id,
      title,
      body,
      _notificationDetails(reminderMode),
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

  void _updateDebug(ReminderDebugState next) {
    _debugState = next;
    _onDebugStateChanged?.call(next);
  }
}

String channelIdForReminderMode(ReminderMode reminderMode) {
  return switch (reminderMode) {
    ReminderMode.soft => NotificationService.softChannelId,
    ReminderMode.vibration => NotificationService.vibrationChannelId,
    ReminderMode.alarm => NotificationService.alarmChannelId,
  };
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
