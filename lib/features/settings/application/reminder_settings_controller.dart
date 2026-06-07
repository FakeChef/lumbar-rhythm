import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../../core/notifications/notification_service.dart';
import '../../posture/data/posture_session_repository.dart';
import '../data/reminder_settings_repository.dart';
import '../domain/reminder_settings.dart';

final reminderSettingsControllerProvider =
    AsyncNotifierProvider<ReminderSettingsController, ReminderSettings>(
  ReminderSettingsController.new,
);

class ReminderSettingsController extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() {
    return ref.watch(reminderSettingsRepositoryProvider).load();
  }

  Future<void> setRemindersEnabled(bool value) {
    return _saveCurrent((settings) {
      return settings.copyWith(remindersEnabled: value);
    });
  }

  Future<void> setSittingIntervalMinutes(int value) {
    return _saveCurrent((settings) {
      return settings.copyWith(sittingIntervalMinutes: value);
    });
  }

  Future<void> setStandingIntervalMinutes(int value) {
    return _saveCurrent((settings) {
      return settings.copyWith(standingIntervalMinutes: value);
    });
  }

  Future<void> _saveCurrent(
    ReminderSettings Function(ReminderSettings settings) update,
  ) async {
    final current = state.value ?? ReminderSettings.defaults;
    final next = update(current);
    state = AsyncData(next);
    await ref.read(reminderSettingsRepositoryProvider).save(next);
    notifyAppDataChanged(ref);
    try {
      final openSession =
          await ref.read(postureSessionRepositoryProvider).loadOpenSession();
      await ref.read(notificationServiceProvider).scheduleNextReminders(
            enabled: next.remindersEnabled,
            sittingIntervalMinutes: next.sittingIntervalMinutes,
            standingIntervalMinutes: next.standingIntervalMinutes,
            currentPosture: openSession?.type,
          );
    } catch (_) {
      // Settings remain saved even if the platform cannot schedule reminders.
    }
  }
}
