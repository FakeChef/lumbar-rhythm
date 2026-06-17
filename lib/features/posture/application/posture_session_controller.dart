import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/reminders/system_timer_handoff_service.dart';
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

const postureCountdownRefreshInterval = Duration(seconds: 15);

class PostureSessionController extends AsyncNotifier<PostureSession?> {
  Timer? _countdownStatusTimer;

  @override
  Future<PostureSession?> build() async {
    ref.onDispose(() => _countdownStatusTimer?.cancel());
    final session =
        await ref.watch(postureSessionRepositoryProvider).loadOpenSession();
    await _refreshCountdownStatus(session);
    _configureCountdownStatusRefresh(session);
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

  Future<void> stopCurrent() {
    return endCurrent();
  }

  Future<void> completeReminder() async {
    await ref.read(notificationServiceProvider).completePostureCountdown();
    ref.read(postureReminderStatusProvider.notifier).state = '当前已休息，坐/站倒计时已停止。';
    _stopCountdownStatusRefresh();
    await endCurrent();
  }

  Future<void> snoozeReminder({int minutes = 10}) async {
    final result = await ref
        .read(notificationServiceProvider)
        .snoozePostureCountdown(minutes: minutes);
    final session = state.valueOrNull;
    if (result.success && session != null && result.session?.dueAt != null) {
      ref.read(postureReminderStatusProvider.notifier).state =
          _countdownRunningMessage(session.type, result.session!.dueAt!);
      _configureCountdownStatusRefresh(session);
      return;
    }
    ref.read(postureReminderStatusProvider.notifier).state =
        result.message.isNotEmpty ? result.message : '延后失败，请到设置页进行提醒检测。';
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
    await _startCountdownFor(session, settings, sittingIntervalMinutes: 1);
    ref.invalidate(dailyReportControllerProvider);
    notifyAppDataChanged(ref);
  }

  Future<void> switchTo(PostureType type) async {
    if (type != PostureType.sitting &&
        type != PostureType.standing &&
        type != PostureType.walking &&
        type != PostureType.resting) {
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
        // not block countdown cancellation or the current session update.
      }
    }
    state = AsyncData(session);
    ref.invalidate(dailyReportControllerProvider);
    notifyAppDataChanged(ref);
    if (type == PostureType.sitting || type == PostureType.standing) {
      await _handoffToSystemTimerFor(session, settings);
    } else {
      await _stopCountdownForNonTimedPosture();
    }
  }

  Future<void> endCurrent() async {
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    await ref.read(postureSessionRepositoryProvider).endCurrent(
          sittingThresholdMinutes: settings.sittingIntervalMinutes,
          standingThresholdMinutes: settings.standingIntervalMinutes,
          walkingThresholdMinutes: settings.walkingIntervalMinutes,
        );
    state = const AsyncData(null);
    ref.read(postureReminderStatusProvider.notifier).state =
        '当前记录已停止。如系统闹钟或计时器仍在运行，请在系统时钟中取消。';
    notifyAppDataChanged(ref);
    _stopCountdownStatusRefresh();
    await ref.read(notificationServiceProvider).stopPostureCountdown();
  }

  Future<void> rescheduleForCurrent() async {
    final session = state.valueOrNull;
    if (session == null ||
        session.type == PostureType.walking ||
        session.type == PostureType.resting) {
      await _stopCountdownForNonTimedPosture();
      return;
    }
    ref.read(postureReminderStatusProvider.notifier).state =
        _systemTimerHandoffMessage(session.type);
    await ref.read(notificationServiceProvider).stopPostureCountdown();
  }

  Future<void> handleAppResumed() async {
    final session = state.valueOrNull ??
        await ref.read(postureSessionRepositoryProvider).loadOpenSession();
    await _refreshCountdownStatus(session);
    _configureCountdownStatusRefresh(session);
  }

  Future<void> _handoffToSystemTimerFor(
    PostureSession session,
    ReminderSettings settings, {
    int? sittingIntervalMinutes,
    int? standingIntervalMinutes,
  }) async {
    _stopCountdownStatusRefresh();
    await ref.read(notificationServiceProvider).stopPostureCountdown();
    if (!settings.remindersEnabled) {
      ref.read(postureReminderStatusProvider.notifier).state = '提醒未开启，可在设置中打开。';
      return;
    }

    final intervalMinutes = session.type == PostureType.standing
        ? standingIntervalMinutes ?? settings.standingIntervalMinutes
        : sittingIntervalMinutes ?? settings.sittingIntervalMinutes;
    final result = await ref.read(systemTimerHandoffServiceProvider).startTimer(
          duration: Duration(minutes: intervalMinutes),
          message: session.type == PostureType.standing
              ? '久站提醒：该坐下休息一下'
              : '久坐提醒：该起来活动一下',
        );
    ref.read(postureReminderStatusProvider.notifier).state = result.success
        ? _systemTimerHandoffMessage(session.type)
        : '无法打开系统闹钟或计时器，请手动打开系统时钟设置提醒。';
  }

  Future<void> _startCountdownFor(
    PostureSession session,
    ReminderSettings settings, {
    int? sittingIntervalMinutes,
    int? standingIntervalMinutes,
  }) async {
    if (!settings.remindersEnabled) {
      await ref.read(notificationServiceProvider).stopPostureCountdown();
      ref.read(postureReminderStatusProvider.notifier).state = '提醒未开启，可在设置中打开。';
      _stopCountdownStatusRefresh();
      return;
    }

    final intervalMinutes = session.type == PostureType.standing
        ? standingIntervalMinutes ?? settings.standingIntervalMinutes
        : sittingIntervalMinutes ?? settings.sittingIntervalMinutes;
    final startedAt = DateTime.now();
    final startResult =
        await ref.read(notificationServiceProvider).startPostureCountdown(
              postureType: session.type,
              duration: Duration(minutes: intervalMinutes),
              reminderMode: settings.reminderMode,
              startedAt: startedAt,
            );
    if (!startResult.success) {
      ref.read(postureReminderStatusProvider.notifier).state =
          startResult.code == 'notification_permission_missing' ||
                  startResult.code == 'notification_permission_denied'
              ? '通知权限未开启，无法显示提醒。请先开启通知权限。'
              : '倒计时启动失败，请到设置页进行提醒检测。';
      _stopCountdownStatusRefresh();
      return;
    }
    final dueAt =
        startResult.dueAt ?? startedAt.add(Duration(minutes: intervalMinutes));
    final runningMessage = _countdownRunningMessage(session.type, dueAt);
    final permissionMessage =
        startResult.permission?.exactAlarmAvailable == false ||
                startResult.session?.exactAlarmAvailable == false
            ? ' 准时提醒权限未开启，提醒可能延迟。建议开启“闹钟和提醒”权限。'
            : '';
    ref.read(postureReminderStatusProvider.notifier).state =
        '$runningMessage$permissionMessage';
    _configureCountdownStatusRefresh(session);
  }

  Future<void> _stopCountdownForNonTimedPosture() async {
    await ref.read(notificationServiceProvider).stopPostureCountdown();
    ref.read(postureReminderStatusProvider.notifier).state =
        '当前记录已停止。如系统闹钟或计时器仍在运行，请在系统时钟中取消。';
    _stopCountdownStatusRefresh();
  }

  void _configureCountdownStatusRefresh(PostureSession? session) {
    _countdownStatusTimer?.cancel();
    if (session == null ||
        (session.type != PostureType.sitting &&
            session.type != PostureType.standing)) {
      return;
    }
    _countdownStatusTimer = Timer.periodic(
      postureCountdownRefreshInterval,
      (_) => unawaited(_refreshCountdownStatus(state.valueOrNull)),
    );
  }

  void _stopCountdownStatusRefresh() {
    _countdownStatusTimer?.cancel();
    _countdownStatusTimer = null;
  }

  Future<void> _refreshCountdownStatus(PostureSession? session) async {
    if (session == null ||
        (session.type != PostureType.sitting &&
            session.type != PostureType.standing)) {
      ref.read(postureReminderStatusProvider.notifier).state = '当前状态不需要系统提醒。';
      return;
    }
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    if (!settings.remindersEnabled) {
      ref.read(postureReminderStatusProvider.notifier).state = '提醒未开启，可在设置中打开。';
      return;
    }
    ref.read(postureReminderStatusProvider.notifier).state =
        _systemTimerHandoffMessage(session.type);
  }

  String _systemTimerHandoffMessage(PostureType type) {
    return type == PostureType.standing
        ? '当前状态：正在站。已交给系统提醒。'
        : '当前状态：正在坐。已交给系统提醒。';
  }

  String _countdownRunningMessage(PostureType type, DateTime dueAt) {
    final remaining = dueAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return _countdownDueMessage(type);
    }
    final minutes = (remaining.inSeconds / 60).ceil();
    return type == PostureType.standing
        ? '当前状态：正在站。久站倒计时中，剩余约 $minutes 分钟。'
        : '当前状态：正在坐。久坐倒计时中，剩余约 $minutes 分钟。';
  }

  String _countdownDueMessage(PostureType type) {
    return type == PostureType.standing
        ? '提醒已到期。你已经连续站超过建议时间。'
        : '提醒已到期。你已经连续坐超过建议时间。';
  }
}
