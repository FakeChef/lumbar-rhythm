import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../../core/notifications/notification_service.dart';
import '../../actions/application/posture_reminder_rehab_link.dart';
import '../../actions/data/rehab_repository.dart';
import '../../reports/application/daily_report_controller.dart';
import '../../settings/data/reminder_settings_repository.dart';
import '../../settings/domain/reminder_settings.dart';
import '../data/posture_session_repository.dart';
import '../domain/posture_session.dart';

final postureClockProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final postureSessionControllerProvider =
    AsyncNotifierProvider<PostureSessionController, PostureSession?>(
  PostureSessionController.new,
);

final postureReminderStatusProvider = StateProvider<String?>((ref) => null);

const postureForegroundReminderCheckInterval = Duration(seconds: 15);

class PostureSessionController extends AsyncNotifier<PostureSession?> {
  Timer? _foregroundTimer;
  String? _foregroundReminderSessionKey;
  String? _foregroundReminderAttemptSessionKey;
  String? _lifecycleCatchupSessionKey;
  int? _foregroundSittingIntervalMinutes;
  int? _foregroundStandingIntervalMinutes;
  String? _foregroundIntervalSessionKey;
  int _scheduleRequestVersion = 0;
  Future<void> _scheduleQueue = Future<void>.value();

  @override
  Future<PostureSession?> build() async {
    ref.onDispose(() => _foregroundTimer?.cancel());
    final session =
        await ref.watch(postureSessionRepositoryProvider).loadOpenSession();
    await _configureForegroundWatcher(session);
    if (session != null) {
      unawaited(_scheduleFor(session));
    }
    return session;
  }

  Future<void> startSitting() {
    return switchTo(PostureType.sitting);
  }

  Future<void> startWalking() {
    return switchTo(PostureType.walking);
  }

  Future<void> startStanding() {
    return switchTo(PostureType.standing);
  }

  Future<void> startTodaySittingChainTest() async {
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    final session = await ref.read(postureSessionRepositoryProvider).switchTo(
          type: PostureType.sitting,
          sittingThresholdMinutes: 1,
          standingThresholdMinutes: settings.standingIntervalMinutes,
          walkingThresholdMinutes: settings.walkingIntervalMinutes,
        );
    state = AsyncData(session);
    ref.read(postureReminderStatusProvider.notifier).state = null;
    await _configureForegroundWatcher(session, sittingIntervalMinutes: 1);
    final scheduled =
        await ref.read(notificationServiceProvider).scheduleNextReminders(
              enabled: settings.remindersEnabled,
              sittingIntervalMinutes: 1,
              standingIntervalMinutes: settings.standingIntervalMinutes,
              walkingIntervalMinutes: settings.walkingIntervalMinutes,
              reminderMode: settings.reminderMode,
              currentPosture: session.type,
              currentSessionStartedAt: session.startedAt,
            );
    ref.read(postureReminderStatusProvider.notifier).state =
        _scheduleStatusMessage(
      session: session,
      settings: settings,
      scheduled: scheduled,
      sittingIntervalMinutes: 1,
    );
  }

  Future<void> stopCurrent() {
    return endCurrent();
  }

  Future<void> switchTo(PostureType type) async {
    if (type != PostureType.sitting &&
        type != PostureType.standing &&
        type != PostureType.walking) {
      return;
    }
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    final previous =
        await ref.read(postureSessionRepositoryProvider).loadOpenSession();
    final session = await ref.read(postureSessionRepositoryProvider).switchTo(
          type: type,
          sittingThresholdMinutes: settings.sittingIntervalMinutes,
          standingThresholdMinutes: settings.standingIntervalMinutes,
          walkingThresholdMinutes: settings.walkingIntervalMinutes,
        );
    if (previous?.type == PostureType.sitting && type == PostureType.walking) {
      try {
        await PostureReminderRehabLink(ref.read(rehabRepositoryProvider))
            .recordSittingBreak(createdAt: DateTime.now());
      } catch (_) {
        // The posture switch is the primary action; rehab link failures should
        // not block reminder cancellation or the current session update.
      }
    }
    state = AsyncData(session);
    ref.read(postureReminderStatusProvider.notifier).state = null;
    ref.invalidate(dailyReportControllerProvider);
    notifyAppDataChanged(ref);
    await _configureForegroundWatcher(session);
    await _scheduleFor(session);
  }

  Future<void> endCurrent() async {
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    await ref.read(postureSessionRepositoryProvider).endCurrent(
          sittingThresholdMinutes: settings.sittingIntervalMinutes,
          standingThresholdMinutes: settings.standingIntervalMinutes,
          walkingThresholdMinutes: settings.walkingIntervalMinutes,
        );
    state = const AsyncData(null);
    ref.read(postureReminderStatusProvider.notifier).state = null;
    notifyAppDataChanged(ref);
    _stopForegroundMonitor();
    await _scheduleFor(null);
  }

  Future<void> rescheduleForCurrent() async {
    await _scheduleFor(state.valueOrNull);
  }

  Future<void> handleAppResumed() async {
    final session = state.valueOrNull ??
        await ref.read(postureSessionRepositoryProvider).loadOpenSession();
    if (session == null) {
      _stopForegroundMonitor();
      return;
    }
    await _configureForegroundWatcher(session, runInitialCheck: false);
    await _checkForegroundReminder(session, 'lifecycleCatchup');
  }

  Future<void> _scheduleFor(PostureSession? session) {
    final version = ++_scheduleRequestVersion;
    final next = _scheduleQueue.then(
      (_) => _runLatestScheduleFor(session, version),
    );
    _scheduleQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _runLatestScheduleFor(
    PostureSession? session,
    int version,
  ) async {
    if (version != _scheduleRequestVersion) {
      return;
    }
    try {
      final settings =
          await ref.read(reminderSettingsRepositoryProvider).load();
      if (version != _scheduleRequestVersion) {
        return;
      }
      final scheduled =
          await ref.read(notificationServiceProvider).scheduleNextReminders(
                enabled: settings.remindersEnabled,
                sittingIntervalMinutes: settings.sittingIntervalMinutes,
                standingIntervalMinutes: settings.standingIntervalMinutes,
                walkingIntervalMinutes: settings.walkingIntervalMinutes,
                reminderMode: settings.reminderMode,
                currentPosture: session?.type,
                currentSessionStartedAt: session?.startedAt,
              );
      if (version == _scheduleRequestVersion) {
        ref.read(postureReminderStatusProvider.notifier).state =
            _scheduleStatusMessage(
          session: session,
          settings: settings,
          scheduled: scheduled,
        );
      }
    } catch (error) {
      ref.read(notificationServiceProvider).recordError(error);
      if (version == _scheduleRequestVersion) {
        ref.read(postureReminderStatusProvider.notifier).state =
            _scheduleFailureMessage(session);
      }
      // Posture changes remain saved even if the platform cannot schedule.
    }
  }

  String? _scheduleStatusMessage({
    required PostureSession? session,
    required ReminderSettings settings,
    required bool scheduled,
    int? sittingIntervalMinutes,
    int? standingIntervalMinutes,
  }) {
    if (session == null ||
        (session.type != PostureType.sitting &&
            session.type != PostureType.standing)) {
      return null;
    }
    if (!settings.remindersEnabled) {
      return '提醒未开启，可在设置中打开。';
    }
    final notificationPermissionDenied = ref
            .read(notificationServiceProvider)
            .debugState
            .lastErrorMessage
            ?.contains('通知权限') ??
        false;
    if (notificationPermissionDenied) {
      return '通知权限未开启，可在设置中开启。';
    }
    if (!scheduled) {
      return _scheduleFailureMessage(session);
    }
    final intervalMinutes = session.type == PostureType.standing
        ? standingIntervalMinutes ?? settings.standingIntervalMinutes
        : sittingIntervalMinutes ?? settings.sittingIntervalMinutes;
    final delayMinutes = reminderDelayMinutes(
      intervalMinutes: intervalMinutes,
      sessionStartedAt: session.startedAt,
    );
    final postureLabel = session.type == PostureType.standing ? '久站' : '久坐';
    if (delayMinutes <= 0) {
      return '前台提醒已开启，很快会提醒。';
    }
    return '$postureLabel提醒已开启，预计约 $delayMinutes 分钟后提醒。';
  }

  String _scheduleFailureMessage(PostureSession? session) {
    if (session == null ||
        (session.type != PostureType.sitting &&
            session.type != PostureType.standing)) {
      return '提醒没有安排成功，请检查系统通知设置。';
    }
    final postureLabel = session.type == PostureType.standing ? '久站' : '久坐';
    return '$postureLabel提醒没有安排成功，请检查系统通知设置。';
  }

  Future<void> _configureForegroundWatcher(
    PostureSession? session, {
    int? sittingIntervalMinutes,
    int? standingIntervalMinutes,
    bool runInitialCheck = true,
  }) async {
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    if (!settings.remindersEnabled ||
        session == null ||
        (session.type != PostureType.sitting &&
            session.type != PostureType.standing)) {
      _stopForegroundMonitor();
      return;
    }
    final sessionKey = _sessionKey(session);
    final usePreviousOverride = sessionKey != null &&
        sessionKey == _foregroundIntervalSessionKey &&
        sittingIntervalMinutes == null &&
        standingIntervalMinutes == null;
    _startForegroundMonitor(
      session,
      sittingIntervalMinutes: sittingIntervalMinutes ??
          (usePreviousOverride ? _foregroundSittingIntervalMinutes : null) ??
          settings.sittingIntervalMinutes,
      standingIntervalMinutes: standingIntervalMinutes ??
          (usePreviousOverride ? _foregroundStandingIntervalMinutes : null) ??
          settings.standingIntervalMinutes,
      runInitialCheck: runInitialCheck,
    );
  }

  void _startForegroundMonitor(
    PostureSession session, {
    required int sittingIntervalMinutes,
    required int standingIntervalMinutes,
    bool runInitialCheck = true,
  }) {
    _foregroundTimer?.cancel();
    _foregroundIntervalSessionKey = _sessionKey(session);
    _foregroundSittingIntervalMinutes = sittingIntervalMinutes;
    _foregroundStandingIntervalMinutes = standingIntervalMinutes;
    final dueAt = _dueAtFor(
      session,
      sittingIntervalMinutes: sittingIntervalMinutes,
      standingIntervalMinutes: standingIntervalMinutes,
    );
    ref.read(notificationServiceProvider).updateHybridReminderState(
          foregroundWatcherActive: true,
          foregroundDueAt: dueAt,
          postureType: session.type,
          sessionStartedAt: session.startedAt,
        );
    _foregroundTimer = Timer.periodic(
      postureForegroundReminderCheckInterval,
      (_) {
        unawaited(_checkForegroundReminder());
      },
    );
    if (runInitialCheck) {
      unawaited(_checkForegroundReminder(session));
    }
  }

  void _stopForegroundMonitor() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    _foregroundReminderAttemptSessionKey = null;
    _foregroundIntervalSessionKey = null;
    _foregroundSittingIntervalMinutes = null;
    _foregroundStandingIntervalMinutes = null;
    ref.read(notificationServiceProvider).updateHybridReminderState(
          foregroundWatcherActive: false,
        );
  }

  Future<void> _checkForegroundReminder(
      [PostureSession? currentSession,
      String triggeredBy = 'foregroundWatcher']) async {
    final session = currentSession ?? state.valueOrNull;
    final sessionKey = _sessionKey(session);
    if (session == null ||
        sessionKey == null ||
        sessionKey == _foregroundReminderSessionKey ||
        sessionKey == _foregroundReminderAttemptSessionKey ||
        (triggeredBy == 'lifecycleCatchup' &&
            sessionKey == _lifecycleCatchupSessionKey) ||
        (session.type != PostureType.sitting &&
            session.type != PostureType.standing)) {
      return;
    }
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    if (!settings.remindersEnabled) {
      return;
    }
    final dueAt = _dueAtFor(
      session,
      sittingIntervalMinutes:
          _foregroundSittingIntervalMinutes ?? settings.sittingIntervalMinutes,
      standingIntervalMinutes: _foregroundStandingIntervalMinutes ??
          settings.standingIntervalMinutes,
    );
    if (DateTime.now().isBefore(dueAt)) {
      return;
    }
    _foregroundReminderAttemptSessionKey = sessionKey;
    var shown = false;
    try {
      shown =
          await ref.read(notificationServiceProvider).showPostureDueReminder(
                posture: session.type,
                reminderMode: settings.reminderMode,
              );
      if (shown) {
        final firedAt = DateTime.now();
        _foregroundReminderSessionKey = sessionKey;
        if (triggeredBy == 'lifecycleCatchup') {
          _lifecycleCatchupSessionKey = sessionKey;
        }
        ref.read(notificationServiceProvider).recordHybridReminderFired(
              triggeredBy: triggeredBy,
              firedAt: firedAt,
              postureType: session.type,
              sessionStartedAt: session.startedAt,
              dueAt: dueAt,
            );
        await ref
            .read(notificationServiceProvider)
            .cancelScheduledReminderForPosture(session.type);
      }
    } catch (error) {
      ref.read(notificationServiceProvider).recordHybridReminderError(error);
      rethrow;
    } finally {
      if (_foregroundReminderAttemptSessionKey == sessionKey) {
        _foregroundReminderAttemptSessionKey = null;
      }
    }
    ref.read(postureReminderStatusProvider.notifier).state = shown
        ? _triggeredStatusMessage(session, triggeredBy)
        : '提醒触发失败，请检查系统通知设置。';
  }

  DateTime _dueAtFor(
    PostureSession session, {
    required int sittingIntervalMinutes,
    required int standingIntervalMinutes,
  }) {
    final intervalMinutes = session.type == PostureType.standing
        ? standingIntervalMinutes
        : sittingIntervalMinutes;
    return session.startedAt.add(Duration(minutes: intervalMinutes));
  }

  String? _sessionKey(PostureSession? session) {
    if (session == null) {
      return null;
    }
    return '${session.type.name}-${session.startedAt.toIso8601String()}';
  }

  String _triggeredStatusMessage(PostureSession session, String triggeredBy) {
    final postureLabel = session.type == PostureType.standing ? '久站' : '久坐';
    if (triggeredBy == 'lifecycleCatchup') {
      return '刚刚补发了一条$postureLabel提醒。';
    }
    return session.type == PostureType.standing
        ? '久站提醒已触发，可以坐下休息一下。'
        : '久坐提醒已触发，可以起身走一走。';
  }
}
