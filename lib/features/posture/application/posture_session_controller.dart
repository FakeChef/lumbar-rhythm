import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../../core/notifications/notification_service.dart';
import '../../actions/application/posture_reminder_rehab_link.dart';
import '../../actions/data/rehab_repository.dart';
import '../../reports/application/daily_report_controller.dart';
import '../../settings/data/reminder_settings_repository.dart';
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

class PostureSessionController extends AsyncNotifier<PostureSession?> {
  Timer? _foregroundTimer;
  int? _foregroundReminderSessionId;

  @override
  Future<PostureSession?> build() async {
    ref.onDispose(() => _foregroundTimer?.cancel());
    final session =
        await ref.watch(postureSessionRepositoryProvider).loadOpenSession();
    _startForegroundMonitor(session);
    unawaited(_scheduleFor(session?.type));
    return session;
  }

  Future<void> startSitting() {
    return switchTo(PostureType.sitting);
  }

  Future<void> startWalking() {
    return switchTo(PostureType.walking);
  }

  Future<void> stopCurrent() {
    return endCurrent();
  }

  Future<void> switchTo(PostureType type) async {
    if (type != PostureType.sitting && type != PostureType.walking) {
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
    _startForegroundMonitor(session);
    unawaited(_scheduleFor(session.type));
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
    unawaited(_scheduleFor(null));
  }

  Future<void> rescheduleForCurrent() async {
    await _scheduleFor(state.value?.type);
  }

  Future<void> _scheduleFor(PostureType? posture) async {
    try {
      final settings =
          await ref.read(reminderSettingsRepositoryProvider).load();
      await ref.read(notificationServiceProvider).scheduleNextReminders(
            enabled: settings.remindersEnabled,
            sittingIntervalMinutes: settings.sittingIntervalMinutes,
            standingIntervalMinutes: settings.standingIntervalMinutes,
            walkingIntervalMinutes: settings.walkingIntervalMinutes,
            reminderMode: settings.reminderMode,
            currentPosture: posture,
          );
    } catch (_) {
      // Posture changes remain saved even if the platform cannot schedule.
    }
  }

  void _startForegroundMonitor(PostureSession? session) {
    _foregroundTimer?.cancel();
    _foregroundReminderSessionId = null;
    if (session == null ||
        (session.type != PostureType.sitting &&
            session.type != PostureType.walking)) {
      return;
    }
    _foregroundTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_checkForegroundReminder());
    });
    unawaited(_checkForegroundReminder(session));
  }

  void _stopForegroundMonitor() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    _foregroundReminderSessionId = null;
  }

  Future<void> _checkForegroundReminder([PostureSession? currentSession]) async {
    final session = currentSession ?? state.valueOrNull;
    if (session == null ||
        session.id == _foregroundReminderSessionId ||
        (session.type != PostureType.sitting &&
            session.type != PostureType.walking)) {
      return;
    }
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    if (!settings.remindersEnabled) {
      return;
    }
    final threshold = Duration(
      minutes: session.type == PostureType.walking
          ? settings.walkingIntervalMinutes
          : settings.sittingIntervalMinutes,
    );
    if (DateTime.now().difference(session.startedAt) < threshold) {
      return;
    }
    _foregroundReminderSessionId = session.id;
    final shown =
        await ref.read(notificationServiceProvider).showPostureDueReminder(
              posture: session.type,
              reminderMode: settings.reminderMode,
            );
    if (shown) {
      await ref
          .read(notificationServiceProvider)
          .cancelScheduledReminderForPosture(session.type);
    }
    ref.read(postureReminderStatusProvider.notifier).state = shown
        ? (session.type == PostureType.walking
            ? '走动提醒已触发，可以坐下休息一下。'
            : '久坐提醒已触发，可以起身走一走。')
        : '提醒触发失败，请检查系统通知设置。';
  }
}
