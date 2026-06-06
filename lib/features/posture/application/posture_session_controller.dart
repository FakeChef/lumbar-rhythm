import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
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
  Future<PostureSession?> build() {
    return ref.watch(postureSessionRepositoryProvider).loadOpenSession();
  }

  Future<void> switchTo(PostureType type) async {
    final session = await ref.read(postureSessionRepositoryProvider).switchTo(
          type: type,
        );
    state = AsyncData(session);
    ref.invalidate(dailyReportControllerProvider);
    await _scheduleFor(session.type);
  }

  Future<void> endCurrent() async {
    await ref.read(postureSessionRepositoryProvider).endCurrent();
    state = const AsyncData(null);
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
            currentPosture: posture,
          );
    } catch (_) {
      // Posture changes remain saved even if the platform cannot schedule.
    }
  }
}
