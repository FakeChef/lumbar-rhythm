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
      await _startCountdownFor(session, settings);
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
    ref.read(postureReminderStatusProvider.notifier).state = '当前已休息，坐/站倒计时已停止。';
    notifyAppDataChanged(ref);
    _stopCountdownStatusRefresh();
    await ref.read(notificationServiceProvider).stopPostureCountdown();
  }

  Future<void> rescheduleForCurrent() async {
    final session = state.valueOrNull;
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    if (session == null ||
        session.type == PostureType.walking ||
        session.type == PostureType.resting) {
      await _stopCountdownForNonTimedPosture();
      return;
    }
    await _startCountdownFor(session, settings);
  }

  Future<void> handleAppResumed() async {
    final session = state.valueOrNull ??
        await ref.read(postureSessionRepositoryProvider).loadOpenSession();
    await _refreshCountdownStatus(session);
    _configureCountdownStatusRefresh(session);
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
    final started =
        await ref.read(notificationServiceProvider).startPostureCountdown(
              postureType: session.type,
              duration: Duration(minutes: intervalMinutes),
              reminderMode: settings.reminderMode,
              startedAt: startedAt,
            );
    if (!started) {
      final debugState = ref.read(notificationServiceProvider).debugState;
      ref.read(postureReminderStatusProvider.notifier).state = debugState
              .lastCountdownFailureMessage ??
          '\u7cfb\u7edf\u63d0\u9192\u542f\u52a8\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5\u3002';
      _stopCountdownStatusRefresh();
      return;
    }
    final dueAt = startedAt.add(Duration(minutes: intervalMinutes));
    ref.read(postureReminderStatusProvider.notifier).state =
        '${_countdownRunningMessage(session.type, dueAt)} 系统提醒已开启。';
    _configureCountdownStatusRefresh(session);
  }

  Future<void> _stopCountdownForNonTimedPosture() async {
    await ref.read(notificationServiceProvider).stopPostureCountdown();
    ref.read(postureReminderStatusProvider.notifier).state = '当前已休息，坐/站倒计时已停止。';
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
      ref.read(postureReminderStatusProvider.notifier).state =
          '当前状态不需要久坐/久站倒计时。';
      return;
    }
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    if (!settings.remindersEnabled) {
      ref.read(postureReminderStatusProvider.notifier).state = '提醒未开启，可在设置中打开。';
      return;
    }
    final countdown =
        await ref.read(notificationServiceProvider).getPostureCountdownState();
    if (countdown.postureType == session.type && countdown.dueAt != null) {
      final message = countdown.running
          ? _countdownRunningMessage(session.type, countdown.dueAt!)
          : _countdownDueMessage(session.type);
      ref.read(postureReminderStatusProvider.notifier).state = message;
      return;
    }
    ref.read(postureReminderStatusProvider.notifier).state =
        _countdownRunningMessage(
      session.type,
      session.startedAt.add(
        Duration(
          minutes: session.type == PostureType.standing
              ? settings.standingIntervalMinutes
              : settings.sittingIntervalMinutes,
        ),
      ),
    );
  }

  String _countdownRunningMessage(PostureType type, DateTime dueAt) {
    final remaining = dueAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return _countdownDueMessage(type);
    }
    final minutes = (remaining.inSeconds / 60).ceil();
    return type == PostureType.standing
        ? '久站倒计时中，剩余约 $minutes 分钟。'
        : '久坐倒计时中，剩余约 $minutes 分钟。';
  }

  String _countdownDueMessage(PostureType type) {
    return type == PostureType.standing
        ? '久站已到提醒时间，建议现在变换姿势。'
        : '久坐已到提醒时间，建议现在活动一下。';
  }
}
