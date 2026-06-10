import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
}

class PostureCountdownState {
  const PostureCountdownState({
    required this.running,
    this.postureType,
    this.remainingSeconds,
    this.dueAt,
    this.startedAt,
  });

  final bool running;
  final PostureType? postureType;
  final int? remainingSeconds;
  final DateTime? dueAt;
  final DateTime? startedAt;

  bool get isDue {
    final due = dueAt;
    if (running || postureType == null || due == null) {
      return false;
    }
    return !DateTime.now().isBefore(due);
  }

  static PostureCountdownState fromMap(Map<Object?, Object?> map) {
    DateTime? millisToDate(Object? value) {
      if (value is int && value > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    final postureName = map['postureType'];
    return PostureCountdownState(
      running: map['running'] == true,
      postureType: postureName is String
          ? PostureType.values.cast<PostureType?>().firstWhere(
                (type) => type?.name == postureName,
                orElse: () => null,
              )
          : null,
      remainingSeconds: map['remainingSeconds'] is int
          ? map['remainingSeconds'] as int
          : null,
      dueAt: millisToDate(map['dueAtMillis']),
      startedAt: millisToDate(map['startedAtMillis']),
    );
  }
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
    PostureType.walking => const ReminderSchedulePlan(kinds: []),
    PostureType.resting => const ReminderSchedulePlan(
        kinds: [],
      ),
  };
}

int reminderDelayMinutes({
  required int intervalMinutes,
  DateTime? sessionStartedAt,
  DateTime? now,
}) {
  if (sessionStartedAt == null) {
    return intervalMinutes;
  }
  final elapsed = (now ?? DateTime.now()).difference(sessionStartedAt);
  final remaining = Duration(minutes: intervalMinutes) - elapsed;
  if (remaining <= Duration.zero) {
    return 0;
  }
  return (remaining.inSeconds / 60).ceil();
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
    this.notificationsEnabled,
    this.exactNotificationsAvailable,
    this.exactAlarmAllowed,
    this.exactAlarmSdkInt,
    this.lastCountdownFailureCode,
    this.lastCountdownFailureMessage,
    this.lastPostureReminderType,
    this.lastPostureReminderSessionStartedAt,
    this.lastPostureReminderPending,
    this.lastPostureReminderDueAt,
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
  final bool? notificationsEnabled;
  final bool? exactNotificationsAvailable;
  final bool? exactAlarmAllowed;
  final int? exactAlarmSdkInt;
  final String? lastCountdownFailureCode;
  final String? lastCountdownFailureMessage;
  final PostureType? lastPostureReminderType;
  final DateTime? lastPostureReminderSessionStartedAt;
  final bool? lastPostureReminderPending;
  final DateTime? lastPostureReminderDueAt;

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
    bool? notificationsEnabled,
    bool? exactNotificationsAvailable,
    bool? exactAlarmAllowed,
    int? exactAlarmSdkInt,
    String? lastCountdownFailureCode,
    String? lastCountdownFailureMessage,
    PostureType? lastPostureReminderType,
    DateTime? lastPostureReminderSessionStartedAt,
    bool? lastPostureReminderPending,
    DateTime? lastPostureReminderDueAt,
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
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      exactNotificationsAvailable:
          exactNotificationsAvailable ?? this.exactNotificationsAvailable,
      exactAlarmAllowed: exactAlarmAllowed ?? this.exactAlarmAllowed,
      exactAlarmSdkInt: exactAlarmSdkInt ?? this.exactAlarmSdkInt,
      lastCountdownFailureCode: lastCountdownFailureCode,
      lastCountdownFailureMessage: lastCountdownFailureMessage,
      lastPostureReminderType:
          lastPostureReminderType ?? this.lastPostureReminderType,
      lastPostureReminderSessionStartedAt:
          lastPostureReminderSessionStartedAt ??
              this.lastPostureReminderSessionStartedAt,
      lastPostureReminderPending:
          lastPostureReminderPending ?? this.lastPostureReminderPending,
      lastPostureReminderDueAt:
          lastPostureReminderDueAt ?? this.lastPostureReminderDueAt,
    );
  }
}

class ExactAlarmPermissionState {
  const ExactAlarmPermissionState({
    required this.canScheduleExactAlarms,
    required this.sdkInt,
  });

  final bool canScheduleExactAlarms;
  final int? sdkInt;

  factory ExactAlarmPermissionState.fromMap(Map<Object?, Object?> map) {
    return ExactAlarmPermissionState(
      canScheduleExactAlarms: map['canScheduleExactAlarms'] == true,
      sdkInt: map['sdkInt'] is int ? map['sdkInt'] as int : null,
    );
  }

  static const allowed = ExactAlarmPermissionState(
    canScheduleExactAlarms: true,
    sdkInt: null,
  );
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
  static const _testReminderId = 199;
  static const _foregroundTimerTestReminderId = 198;
  static const _tenSecondScheduledTestReminderId = 202;

  // Android notification channel sound and vibration behavior is fixed after
  // channel creation. Use v2 ids so old muted or misconfigured channels do not
  // pollute reminder diagnostics or real posture reminders.
  static const softChannelId = 'lumbar_rhythm_soft_reminders_v2';
  static const vibrationChannelId = 'lumbar_rhythm_vibration_reminders_v2';
  static const alarmChannelId = 'lumbar_rhythm_alarm_reminders_v2';
  static const _channelDescription = '久坐久站和休息节奏提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _postureCountdownChannel =
      MethodChannel('lumbar_rhythm/posture_countdown');
  static const MethodChannel _postureAlarmChannel =
      MethodChannel('lumbar_rhythm/posture_alarm');
  final void Function(ReminderDebugState state)? _onDebugStateChanged;

  bool _timeZonesInitialized = false;
  bool _notificationsInitialized = false;
  Timer? _foregroundTestTimer;
  ReminderDebugState _debugState = const ReminderDebugState();

  NotificationService({
    void Function(ReminderDebugState state)? onDebugStateChanged,
  }) : _onDebugStateChanged = onDebugStateChanged;

  ReminderDebugState get debugState => _debugState;

  Future<bool> startPostureCountdown({
    required PostureType postureType,
    required Duration duration,
    required ReminderMode reminderMode,
    required DateTime startedAt,
  }) async {
    if (postureType != PostureType.sitting &&
        postureType != PostureType.standing) {
      await stopPostureCountdown();
      return false;
    }
    try {
      await initialize();
      final permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        _updateDebug(
          _debugState.copyWith(lastErrorMessage: '系统通知权限未开启。'),
        );
        return false;
      }
      final exactAlarmState = await getExactAlarmPermissionState();
      if (!exactAlarmState.canScheduleExactAlarms) {
        _updateDebug(
          _debugState.copyWith(
            lastErrorMessage:
                '\u7cfb\u7edf\u672a\u5141\u8bb8\u95f9\u949f\u548c\u63d0\u9192\u6743\u9650\uff0c\u8bf7\u5f00\u542f\u540e\u518d\u4f7f\u7528\u5012\u8ba1\u65f6\u63d0\u9192\u3002',
            lastCountdownFailureCode: 'exact_alarm_not_allowed',
            lastCountdownFailureMessage:
                '\u7cfb\u7edf\u672a\u5141\u8bb8\u95f9\u949f\u548c\u63d0\u9192\u6743\u9650\uff0c\u8bf7\u5f00\u542f\u540e\u518d\u4f7f\u7528\u5012\u8ba1\u65f6\u63d0\u9192\u3002',
          ),
        );
        return false;
      }
      final arguments = {
        'postureType': postureType.name,
        'durationSeconds': duration.inSeconds,
        'reminderMode': reminderMode.name,
        'startedAtMillis': startedAt.millisecondsSinceEpoch,
      };
      await _postureCountdownChannel.invokeMethod<void>(
        'startPostureCountdown',
        arguments,
      );
      final alarmStartResult = await _postureAlarmChannel
          .invokeMapMethod<Object?, Object?>('startPostureAlarm', arguments);
      if (alarmStartResult?['success'] == false) {
        final code =
            alarmStartResult?['code']?.toString() ?? 'start_alarm_failed';
        final message = alarmStartResult?['message']?.toString() ??
            '\u7cfb\u7edf\u63d0\u9192\u542f\u52a8\u5931\u8d25';
        _updateDebug(
          _debugState.copyWith(
            lastErrorMessage: message,
            lastCountdownFailureCode: code,
            lastCountdownFailureMessage: message,
          ),
        );
        return false;
      }
      final dueAt = startedAt.add(duration);
      _updateDebug(
        _debugState.copyWith(
          lastPostureReminderType: postureType,
          lastPostureReminderSessionStartedAt: startedAt,
          lastPostureReminderDueAt: dueAt,
          lastReminderMode: reminderMode,
          lastChannelId: channelIdForReminderMode(reminderMode),
          lastErrorMessage: null,
        ),
      );
      return true;
    } catch (error) {
      _updateDebug(
        _debugState.copyWith(
          lastPostureReminderType: postureType,
          lastPostureReminderSessionStartedAt: startedAt,
          lastErrorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> stopPostureCountdown() async {
    try {
      await _postureCountdownChannel.invokeMethod<void>(
        'stopPostureCountdown',
      );
      await _postureAlarmChannel.invokeMethod<void>(
        'cancelPostureAlarm',
      );
      _updateDebug(
        _debugState.copyWith(
          lastPostureReminderPending: false,
          lastErrorMessage: null,
        ),
      );
    } catch (error) {
      _updateDebug(
        _debugState.copyWith(
          lastErrorMessage: error.toString(),
        ),
      );
    }
  }

  Future<PostureCountdownState> getPostureCountdownState() async {
    try {
      final state = await _postureAlarmChannel
          .invokeMapMethod<Object?, Object?>('getPostureAlarmState');
      if (state == null) {
        return const PostureCountdownState(running: false);
      }
      final scheduled = state['scheduled'] == true;
      return PostureCountdownState.fromMap({
        'running': scheduled,
        'postureType': state['postureType'],
        'remainingSeconds': state['remainingSeconds'],
        'dueAtMillis': state['dueAtMillis'],
        'startedAtMillis': state['startedAtMillis'],
      });
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      try {
        final state = await _postureCountdownChannel
            .invokeMapMethod<Object?, Object?>('getPostureCountdownState');
        if (state == null) {
          return const PostureCountdownState(running: false);
        }
        return PostureCountdownState.fromMap(state);
      } catch (_) {
        return const PostureCountdownState(running: false);
      }
    }
  }

  Future<bool> openNotificationSettings() async {
    try {
      final opened = await _postureCountdownChannel.invokeMethod<bool>(
        'openNotificationSettings',
      );
      return opened ?? false;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return false;
    }
  }

  Future<ExactAlarmPermissionState> getExactAlarmPermissionState() async {
    try {
      final state = await _postureAlarmChannel
          .invokeMapMethod<Object?, Object?>('canScheduleExactAlarms');
      final parsed = state == null
          ? ExactAlarmPermissionState.allowed
          : ExactAlarmPermissionState.fromMap(state);
      _updateDebug(
        _debugState.copyWith(
          exactAlarmAllowed: parsed.canScheduleExactAlarms,
          exactAlarmSdkInt: parsed.sdkInt,
        ),
      );
      return parsed;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return ExactAlarmPermissionState.allowed;
    }
  }

  Future<bool> openExactAlarmSettings() async {
    try {
      final opened = await _postureAlarmChannel.invokeMethod<bool>(
        'openExactAlarmSettings',
      );
      return opened ?? false;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return false;
    }
  }

  void recordError(Object error) {
    _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
  }

  Future<void> initialize() async {
    if (_notificationsInitialized) {
      return;
    }

    _ensureTimeZonesInitialized();

    const android = AndroidInitializationSettings('ic_stat_notification');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);
    _notificationsInitialized = true;
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidPermission = await android?.requestNotificationsPermission();

    final granted = androidPermission ?? true;
    _updateDebug(_debugState.copyWith(notificationsEnabled: granted));
    return granted;
  }

  Future<bool?> areNotificationsEnabled() async {
    try {
      await initialize();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled();
      _updateDebug(_debugState.copyWith(notificationsEnabled: enabled));
      return enabled;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return null;
    }
  }

  Future<bool?> canScheduleExactNotifications() async {
    try {
      await initialize();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final available = await android?.canScheduleExactNotifications();
      _updateDebug(
        _debugState.copyWith(exactNotificationsAvailable: available),
      );
      return available;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return null;
    }
  }

  Future<ReminderDebugState> refreshReminderDiagnostics() async {
    await areNotificationsEnabled();
    await canScheduleExactNotifications();
    await getExactAlarmPermissionState();
    return _debugState;
  }

  Future<bool> scheduleNextReminders({
    required bool enabled,
    required int sittingIntervalMinutes,
    required int standingIntervalMinutes,
    int walkingIntervalMinutes = 10,
    ReminderMode reminderMode = ReminderMode.soft,
    PostureType? currentPosture,
    DateTime? currentSessionStartedAt,
  }) async {
    if (!enabled) {
      await cancelScheduledReminders();
      _updateDebug(
        _debugState.copyWith(
          lastScheduleModeResult: '提醒未开启。',
          lastPostureReminderType: currentPosture,
          lastPostureReminderSessionStartedAt: currentSessionStartedAt,
          lastPostureReminderPending: false,
          lastErrorMessage: null,
        ),
      );
      return false;
    }
    if (currentPosture == null ||
        currentPosture == PostureType.walking ||
        currentPosture == PostureType.resting) {
      await cancelScheduledReminders();
      return false;
    }
    _updateDebug(
      _debugState.copyWith(
        lastPostureReminderType: currentPosture,
        lastPostureReminderSessionStartedAt: currentSessionStartedAt,
        lastPostureReminderPending: false,
        lastScheduleModeResult: '手动倒计时模式不安排后台定时提醒。',
        lastErrorMessage: null,
      ),
    );
    return false;
  }

  Future<bool> schedulePostureReminder({
    required PostureType postureType,
    required Duration delay,
    required ReminderMode mode,
    required DateTime sessionStartedAt,
    ReminderScheduleDiagnosticMode diagnosticMode =
        ReminderScheduleDiagnosticMode.inexactAllowWhileIdle,
  }) async {
    if (postureType != PostureType.sitting &&
        postureType != PostureType.standing) {
      await cancelScheduledReminders();
      _updateDebug(
        _debugState.copyWith(
          lastPostureReminderType: postureType,
          lastPostureReminderSessionStartedAt: sessionStartedAt,
          lastPostureReminderPending: false,
          lastScheduleModeResult: '当前姿势不需要安排久坐/久站提醒。',
          lastErrorMessage: null,
        ),
      );
      return false;
    }

    try {
      await initialize();
      final permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        _updateDebug(
          _debugState.copyWith(
            lastPostureReminderType: postureType,
            lastPostureReminderSessionStartedAt: sessionStartedAt,
            lastPostureReminderPending: false,
            lastScheduleModeResult: '通知权限未允许。',
            lastErrorMessage: '系统通知权限未开启。',
          ),
        );
        return false;
      }

      await _plugin.cancel(_sittingReminderId);
      await _plugin.cancel(_standingReminderId);
      _updateDebug(
        _debugState.copyWith(
          pendingNotificationCount: 0,
          pendingNotificationIds: const [],
          scheduledPendingBefore: 0,
          scheduledPendingAfter: 0,
          lastPostureReminderType: postureType,
          lastPostureReminderSessionStartedAt: sessionStartedAt,
          lastPostureReminderPending: false,
          lastScheduleModeResult: '手动倒计时模式不安排后台定时提醒。',
          lastErrorMessage: null,
        ),
      );
      return false;
    } catch (error) {
      _updateDebug(
        _debugState.copyWith(
          lastPostureReminderType: postureType,
          lastPostureReminderSessionStartedAt: sessionStartedAt,
          lastPostureReminderPending: false,
          lastErrorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  Future<bool> scheduleTodaySittingChainTest({
    required ReminderMode reminderMode,
  }) {
    return startPostureCountdown(
      postureType: PostureType.sitting,
      duration: const Duration(minutes: 1),
      reminderMode: reminderMode,
      startedAt: DateTime.now(),
    );
  }

  Future<void> cancelScheduledReminders() async {
    await _plugin.cancel(_sittingReminderId);
    await _plugin.cancel(_standingReminderId);
    await refreshPendingScheduledNotifications();
  }

  Future<void> cancelScheduledReminderForPosture(PostureType posture) async {
    final id = switch (posture) {
      PostureType.sitting => _sittingReminderId,
      PostureType.standing => _standingReminderId,
      PostureType.walking || PostureType.resting => null,
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
      PostureType.standing => showReminderNow(
          mode: reminderMode,
          title: '该坐下休息一下了',
          body: '已经到久站提醒时间，建议坐下放松一会儿。',
          id: _standingReminderId,
        ),
      PostureType.walking || PostureType.resting => false,
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

  Future<bool> showImmediateDiagnosticReminder({
    ReminderMode reminderMode = ReminderMode.soft,
  }) {
    return showReminderNow(
      mode: reminderMode,
      title: '腰椎节奏测试提醒',
      body: '这是一条立即测试提醒',
      id: _testReminderId,
      markAsImmediateTest: true,
    );
  }

  Future<bool> showVibrationDiagnosticReminder() {
    return showReminderNow(
      mode: ReminderMode.vibration,
      title: '腰椎节奏测试提醒',
      body: '这是一条震动测试提醒',
      id: _testReminderId,
      markAsImmediateTest: true,
    );
  }

  Future<bool> showAlarmDiagnosticReminder() {
    return showReminderNow(
      mode: ReminderMode.alarm,
      title: '腰椎节奏测试提醒',
      body: '这是一条响铃测试提醒',
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
    return schedulePostureReminder(
      postureType: PostureType.sitting,
      delay: const Duration(minutes: 1),
      mode: reminderMode,
      sessionStartedAt: DateTime.now(),
      diagnosticMode: diagnosticMode,
    );
  }

  Future<bool> scheduleTenSecondDiagnosticReminder({
    ReminderMode reminderMode = ReminderMode.soft,
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

      final pendingBefore = await _readPendingNotificationIds();
      await _plugin.cancel(_tenSecondScheduledTestReminderId);
      await _scheduleReminder(
        id: _tenSecondScheduledTestReminderId,
        title: '腰椎节奏定时测试',
        body: '这是 10 秒后的定时测试提醒',
        delay: const Duration(seconds: 10),
        reminderMode: reminderMode,
      );
      final pendingAfter = await _readPendingNotificationIds();
      final containsTestId =
          pendingAfter.contains(_tenSecondScheduledTestReminderId);
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
    int minutesFromNow = 0,
    Duration? delay,
    required ReminderMode reminderMode,
    AndroidScheduleMode androidScheduleMode =
        AndroidScheduleMode.inexactAllowWhileIdle,
    String scheduleModeLabel = 'inexactAllowWhileIdle',
  }) async {
    _ensureTimeZonesInitialized();

    final requestedAt = DateTime.now();
    var scheduledAt = tz.TZDateTime.now(tz.local).add(
      delay ?? Duration(minutes: minutesFromNow),
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
  final android = switch (reminderMode) {
    ReminderMode.soft => const AndroidNotificationDetails(
        NotificationService.softChannelId,
        '轻柔坐站提醒',
        channelDescription: NotificationService._channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: false,
      ),
    ReminderMode.vibration => AndroidNotificationDetails(
        NotificationService.vibrationChannelId,
        '震动坐站提醒',
        channelDescription: NotificationService._channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 180, 120, 180]),
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
      ),
  };

  return NotificationDetails(android: android);
}
