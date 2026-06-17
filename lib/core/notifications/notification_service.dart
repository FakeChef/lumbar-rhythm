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
    this.targetDuration,
    this.status,
    this.exactAlarmAvailable,
    this.notificationPermissionGranted,
  });

  final bool running;
  final PostureType? postureType;
  final int? remainingSeconds;
  final DateTime? dueAt;
  final DateTime? startedAt;
  final Duration? targetDuration;
  final String? status;
  final bool? exactAlarmAvailable;
  final bool? notificationPermissionGranted;

  bool get isDue {
    if (status == 'due' && postureType != null) {
      return true;
    }
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
    final status = map['status']?.toString();
    final dueAt =
        millisToDate(map['dueAtMillis'] ?? map['expectedEndTimeMillis']);
    final startedAt =
        millisToDate(map['startedAtMillis'] ?? map['startTimeMillis']);
    final targetDurationMillis = map['targetDurationMillis'];
    bool? optionalBool(String key) {
      return map.containsKey(key) ? map[key] == true : null;
    }

    final running = map['running'] == true ||
        (status == 'running' &&
            dueAt != null &&
            DateTime.now().isBefore(dueAt));
    return PostureCountdownState(
      running: running,
      postureType: postureName is String
          ? PostureType.values.cast<PostureType?>().firstWhere(
                (type) => type?.name == postureName,
                orElse: () => null,
              )
          : null,
      remainingSeconds: map['remainingSeconds'] is int
          ? map['remainingSeconds'] as int
          : null,
      dueAt: dueAt,
      startedAt: startedAt,
      targetDuration: targetDurationMillis is int
          ? Duration(milliseconds: targetDurationMillis)
          : null,
      status: status,
      exactAlarmAvailable: optionalBool('exactAlarmAvailable'),
      notificationPermissionGranted:
          optionalBool('notificationPermissionGranted'),
    );
  }
}

class ReminderPermissionStatus {
  const ReminderPermissionStatus({
    required this.notificationGranted,
    required this.exactAlarmAvailable,
    this.sdkInt,
  });

  final bool notificationGranted;
  final bool exactAlarmAvailable;
  final int? sdkInt;

  static ReminderPermissionStatus fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const ReminderPermissionStatus(
        notificationGranted: true,
        exactAlarmAvailable: true,
      );
    }
    return ReminderPermissionStatus(
      notificationGranted: map['notificationGranted'] != false,
      exactAlarmAvailable: map['exactAlarmAvailable'] != false,
      sdkInt: map['sdkInt'] is int ? map['sdkInt'] as int : null,
    );
  }
}

class PostureCountdownStartResult {
  const PostureCountdownStartResult({
    required this.success,
    required this.mode,
    required this.code,
    required this.message,
    this.dueAt,
    this.session,
    this.permission,
  });

  final bool success;
  final String mode;
  final String code;
  final String message;
  final DateTime? dueAt;
  final PostureCountdownState? session;
  final ReminderPermissionStatus? permission;

  static PostureCountdownStartResult fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const PostureCountdownStartResult(
        success: false,
        mode: 'none',
        code: 'native_start_failed',
        message: '系统倒计时启动失败',
      );
    }
    final dueAtMillis = map['dueAtMillis'];
    final sessionMap = map['session'];
    final permissionMap = map['permission'];
    final session = sessionMap is Map<Object?, Object?>
        ? PostureCountdownState.fromMap(sessionMap)
        : null;
    return PostureCountdownStartResult(
      success: map['success'] == true,
      mode: map['mode']?.toString() ?? 'none',
      code:
          map['errorCode']?.toString() ?? map['code']?.toString() ?? 'unknown',
      message: map['message']?.toString() ?? '',
      dueAt: session?.dueAt ??
          (dueAtMillis is int && dueAtMillis > 0
              ? DateTime.fromMillisecondsSinceEpoch(dueAtMillis)
              : null),
      session: session,
      permission: permissionMap is Map<Object?, Object?>
          ? ReminderPermissionStatus.fromMap(permissionMap)
          : null,
    );
  }

  Map<String, Object?> toDebugMap() {
    return {
      'success': success,
      'mode': mode,
      'code': code,
      'message': message,
      'dueAtMillis': dueAt?.millisecondsSinceEpoch,
    };
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
    this.lastCountdownStartMode,
    this.lastCountdownStartCode,
    this.lastCountdownStartMessage,
    this.lastCountdownStartDueAt,
    this.lastPostureReminderType,
    this.lastPostureReminderSessionStartedAt,
    this.lastPostureReminderPending,
    this.lastPostureReminderDueAt,
    this.activeReminderSessionStatus,
    this.activeReminderRemainingSeconds,
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
  final String? lastCountdownStartMode;
  final String? lastCountdownStartCode;
  final String? lastCountdownStartMessage;
  final DateTime? lastCountdownStartDueAt;
  final PostureType? lastPostureReminderType;
  final DateTime? lastPostureReminderSessionStartedAt;
  final bool? lastPostureReminderPending;
  final DateTime? lastPostureReminderDueAt;
  final String? activeReminderSessionStatus;
  final int? activeReminderRemainingSeconds;

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
    String? lastCountdownStartMode,
    String? lastCountdownStartCode,
    String? lastCountdownStartMessage,
    DateTime? lastCountdownStartDueAt,
    PostureType? lastPostureReminderType,
    DateTime? lastPostureReminderSessionStartedAt,
    bool? lastPostureReminderPending,
    DateTime? lastPostureReminderDueAt,
    String? activeReminderSessionStatus,
    int? activeReminderRemainingSeconds,
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
      lastCountdownStartMode:
          lastCountdownStartMode ?? this.lastCountdownStartMode,
      lastCountdownStartCode:
          lastCountdownStartCode ?? this.lastCountdownStartCode,
      lastCountdownStartMessage:
          lastCountdownStartMessage ?? this.lastCountdownStartMessage,
      lastCountdownStartDueAt:
          lastCountdownStartDueAt ?? this.lastCountdownStartDueAt,
      lastPostureReminderType:
          lastPostureReminderType ?? this.lastPostureReminderType,
      lastPostureReminderSessionStartedAt:
          lastPostureReminderSessionStartedAt ??
              this.lastPostureReminderSessionStartedAt,
      lastPostureReminderPending:
          lastPostureReminderPending ?? this.lastPostureReminderPending,
      lastPostureReminderDueAt:
          lastPostureReminderDueAt ?? this.lastPostureReminderDueAt,
      activeReminderSessionStatus:
          activeReminderSessionStatus ?? this.activeReminderSessionStatus,
      activeReminderRemainingSeconds:
          activeReminderRemainingSeconds ?? this.activeReminderRemainingSeconds,
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
  static const MethodChannel _reminderChannel =
      MethodChannel('lumbar_rhythm/reminder');
  final void Function(ReminderDebugState state)? _onDebugStateChanged;

  bool _timeZonesInitialized = false;
  bool _notificationsInitialized = false;
  Timer? _foregroundTestTimer;
  ReminderDebugState _debugState = const ReminderDebugState();

  NotificationService({
    void Function(ReminderDebugState state)? onDebugStateChanged,
  }) : _onDebugStateChanged = onDebugStateChanged;

  ReminderDebugState get debugState => _debugState;

  Future<PostureCountdownStartResult> startPostureCountdown({
    required PostureType postureType,
    required Duration duration,
    required ReminderMode reminderMode,
    required DateTime startedAt,
  }) async {
    if (postureType != PostureType.sitting &&
        postureType != PostureType.standing) {
      await stopPostureCountdown();
      return const PostureCountdownStartResult(
        success: false,
        mode: 'none',
        code: 'unsupported_posture',
        message: '当前状态不需要坐/站倒计时',
      );
    }
    try {
      await initialize();
      final permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        const result = PostureCountdownStartResult(
          success: false,
          mode: 'none',
          code: 'notification_permission_denied',
          message: '通知权限未开启，无法显示提醒。请先开启通知权限。',
        );
        _updateDebug(
          _debugState.copyWith(
            lastErrorMessage: result.message,
            lastCountdownFailureCode: result.code,
            lastCountdownFailureMessage: result.message,
            lastCountdownStartMode: result.mode,
            lastCountdownStartCode: result.code,
            lastCountdownStartMessage: result.message,
          ),
        );
        return result;
      }
      final arguments = {
        'postureType': postureType.name,
        'durationSeconds': duration.inSeconds,
        'durationMinutes': duration.inMinutes,
        'reminderMode': reminderMode.name,
        'startedAtMillis': startedAt.millisecondsSinceEpoch,
      };
      final method = postureType == PostureType.standing
          ? 'startStandingReminder'
          : 'startSittingReminder';
      final nativeResult =
          await _reminderChannel.invokeMapMethod<Object?, Object?>(
        method,
        arguments,
      );
      final result = PostureCountdownStartResult.fromMap(nativeResult);
      _updateDebug(
        _debugState.copyWith(
          lastPostureReminderType: postureType,
          lastPostureReminderSessionStartedAt:
              result.session?.startedAt ?? startedAt,
          lastPostureReminderDueAt: result.dueAt,
          lastReminderMode: reminderMode,
          lastChannelId: channelIdForReminderMode(reminderMode),
          lastErrorMessage: result.success ? null : result.message,
          lastCountdownFailureCode: result.success ? null : result.code,
          lastCountdownFailureMessage: result.success ? null : result.message,
          lastCountdownStartMode: result.mode,
          lastCountdownStartCode: result.code,
          lastCountdownStartMessage: result.message,
          lastCountdownStartDueAt: result.dueAt,
          notificationsEnabled: result.permission?.notificationGranted,
          exactAlarmAllowed: result.permission?.exactAlarmAvailable,
          exactAlarmSdkInt: result.permission?.sdkInt,
        ),
      );
      return result;
    } catch (error) {
      const result = PostureCountdownStartResult(
        success: false,
        mode: 'none',
        code: 'native_start_failed',
        message: '倒计时启动失败，请到设置页进行提醒检测。',
      );
      _updateDebug(
        _debugState.copyWith(
          lastPostureReminderType: postureType,
          lastPostureReminderSessionStartedAt: startedAt,
          lastErrorMessage: error.toString(),
          lastCountdownFailureCode: result.code,
          lastCountdownFailureMessage: result.message,
          lastCountdownStartMode: result.mode,
          lastCountdownStartCode: result.code,
          lastCountdownStartMessage: result.message,
        ),
      );
      return result;
    }
  }

  Future<void> stopPostureCountdown() async {
    try {
      await _reminderChannel.invokeMapMethod<Object?, Object?>(
        'cancelReminder',
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

  Future<PostureCountdownStartResult> completePostureCountdown() async {
    try {
      final response = await _reminderChannel.invokeMapMethod<Object?, Object?>(
        'completeReminder',
      );
      final result = PostureCountdownStartResult.fromMap(response);
      _updateDebug(
        _debugState.copyWith(
          lastCountdownStartMode: result.mode,
          lastCountdownStartCode: result.code,
          lastCountdownStartMessage: result.message,
          lastErrorMessage: result.success ? null : result.message,
        ),
      );
      return result;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return PostureCountdownStartResult(
        success: false,
        mode: 'none',
        code: 'unknown_error',
        message: error.toString(),
      );
    }
  }

  Future<PostureCountdownStartResult> snoozePostureCountdown({
    int minutes = 10,
  }) async {
    try {
      final response = await _reminderChannel.invokeMapMethod<Object?, Object?>(
        'snoozeReminder',
        {'minutes': minutes},
      );
      final result = PostureCountdownStartResult.fromMap(response);
      _updateDebug(
        _debugState.copyWith(
          lastCountdownStartMode: result.mode,
          lastCountdownStartCode: result.code,
          lastCountdownStartMessage: result.message,
          lastCountdownStartDueAt: result.dueAt,
          lastErrorMessage: result.success ? null : result.message,
        ),
      );
      return result;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return PostureCountdownStartResult(
        success: false,
        mode: 'none',
        code: 'unknown_error',
        message: error.toString(),
      );
    }
  }

  Future<PostureCountdownState> getPostureCountdownState() async {
    try {
      final response = await _reminderChannel
          .invokeMapMethod<Object?, Object?>('getActiveReminderSession');
      final session = response?['session'];
      final permission = response?['permission'];
      if (permission is Map<Object?, Object?>) {
        final parsed = ReminderPermissionStatus.fromMap(permission);
        _updateDebug(
          _debugState.copyWith(
            notificationsEnabled: parsed.notificationGranted,
            exactAlarmAllowed: parsed.exactAlarmAvailable,
            exactAlarmSdkInt: parsed.sdkInt,
          ),
        );
      }
      if (session is Map<Object?, Object?>) {
        final parsed = PostureCountdownState.fromMap(session);
        _updateDebug(
          _debugState.copyWith(
            lastPostureReminderType: parsed.postureType,
            lastPostureReminderSessionStartedAt: parsed.startedAt,
            lastPostureReminderDueAt: parsed.dueAt,
            lastPostureReminderPending: parsed.running,
            activeReminderSessionStatus: parsed.status,
            activeReminderRemainingSeconds: parsed.remainingSeconds,
            notificationsEnabled: parsed.notificationPermissionGranted,
            exactAlarmAllowed: parsed.exactAlarmAvailable,
          ),
        );
        return parsed;
      }
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
    }
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

  Future<ReminderPermissionStatus> getReminderPermissionStatus() async {
    try {
      final state = await _reminderChannel
          .invokeMapMethod<Object?, Object?>('getReminderPermissionStatus');
      final parsed = ReminderPermissionStatus.fromMap(state);
      _updateDebug(
        _debugState.copyWith(
          notificationsEnabled: parsed.notificationGranted,
          exactAlarmAllowed: parsed.exactAlarmAvailable,
          exactAlarmSdkInt: parsed.sdkInt,
        ),
      );
      return parsed;
    } catch (error) {
      _updateDebug(_debugState.copyWith(lastErrorMessage: error.toString()));
      return const ReminderPermissionStatus(
        notificationGranted: true,
        exactAlarmAvailable: true,
      );
    }
  }

  Future<bool> openNotificationSettings() async {
    try {
      final opened = await _reminderChannel.invokeMethod<bool>(
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
      final state = await _reminderChannel
          .invokeMapMethod<Object?, Object?>('getReminderPermissionStatus');
      final permission = ReminderPermissionStatus.fromMap(state);
      final parsed = ExactAlarmPermissionState(
        canScheduleExactAlarms: permission.exactAlarmAvailable,
        sdkInt: permission.sdkInt,
      );
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
      final opened = await _reminderChannel.invokeMethod<bool>(
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
    await getPostureCountdownState();
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

  Future<PostureCountdownStartResult> scheduleTodaySittingChainTest({
    required ReminderMode reminderMode,
    Duration duration = const Duration(minutes: 1),
  }) {
    return startPostureCountdown(
      postureType: PostureType.sitting,
      duration: duration,
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
