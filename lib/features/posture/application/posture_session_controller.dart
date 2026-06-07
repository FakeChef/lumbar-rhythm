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

class PostureSessionController extends AsyncNotifier<PostureSession?> {
  @override
  Future<PostureSession?> build() async {
    final session =
        await ref.watch(postureSessionRepositoryProvider).loadOpenSession();
    await _scheduleFor(session?.type);
    return session;
  }

  Future<void> switchTo(PostureType type) async {
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    final previous =
        await ref.read(postureSessionRepositoryProvider).loadOpenSession();
    final session = await ref.read(postureSessionRepositoryProvider).switchTo(
          type: type,
          sittingThresholdMinutes: settings.sittingIntervalMinutes,
          standingThresholdMinutes: settings.standingIntervalMinutes,
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
    ref.invalidate(dailyReportControllerProvider);
    notifyAppDataChanged(ref);
    await _scheduleFor(session.type);
  }

  Future<void> endCurrent() async {
    final settings = await ref.read(reminderSettingsRepositoryProvider).load();
    await ref.read(postureSessionRepositoryProvider).endCurrent(
          sittingThresholdMinutes: settings.sittingIntervalMinutes,
          standingThresholdMinutes: settings.standingIntervalMinutes,
        );
    state = const AsyncData(null);
    notifyAppDataChanged(ref);
    await _scheduleFor(null);
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
            reminderMode: settings.reminderMode,
            currentPosture: posture,
          );
    } catch (_) {
      // Posture changes remain saved even if the platform cannot schedule.
    }
  }
}
