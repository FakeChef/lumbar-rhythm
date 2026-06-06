import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/notifications/notification_service.dart';
import 'package:lumbar_rhythm/features/posture/data/posture_session_repository.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/settings/application/reminder_settings_controller.dart';
import 'package:lumbar_rhythm/features/settings/data/reminder_settings_repository.dart';
import 'package:lumbar_rhythm/features/settings/domain/reminder_settings.dart';

void main() {
  test('loads default reminder settings', () async {
    final repository = _FakeReminderSettingsRepository();
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    final settings =
        await container.read(reminderSettingsControllerProvider.future);

    expect(settings.remindersEnabled, isTrue);
    expect(settings.sittingIntervalMinutes, 45);
    expect(settings.standingIntervalMinutes, 30);
  });

  test('normalizes interval values to supported bounds and steps', () {
    final settings = ReminderSettings.defaults.copyWith(
      sittingIntervalMinutes: 7,
      standingIntervalMinutes: 127,
    );

    expect(settings.sittingIntervalMinutes, 15);
    expect(settings.standingIntervalMinutes, 120);
  });

  test('saves reminder changes through repository', () async {
    final repository = _FakeReminderSettingsRepository();
    final notificationService = _FakeNotificationService();
    final container = _createContainer(repository, notificationService);
    addTearDown(container.dispose);

    await container.read(reminderSettingsControllerProvider.future);
    await container
        .read(reminderSettingsControllerProvider.notifier)
        .setSittingIntervalMinutes(60);
    await container
        .read(reminderSettingsControllerProvider.notifier)
        .setRemindersEnabled(false);

    final settings = container.read(reminderSettingsControllerProvider).value;

    expect(settings?.sittingIntervalMinutes, 60);
    expect(settings?.remindersEnabled, isFalse);
    expect(repository.savedSettings.last.sittingIntervalMinutes, 60);
    expect(repository.savedSettings.last.remindersEnabled, isFalse);
    expect(notificationService.scheduledSettings.last.enabled, isFalse);
    expect(
        notificationService.scheduledSettings.last.sittingIntervalMinutes, 60);
  });
}

ProviderContainer _createContainer(
  ReminderSettingsRepository repository, [
  NotificationService? notificationService,
]) {
  return ProviderContainer(
    overrides: [
      reminderSettingsRepositoryProvider.overrideWithValue(repository),
      postureSessionRepositoryProvider.overrideWithValue(
        _FakePostureSessionRepository(),
      ),
      if (notificationService != null)
        notificationServiceProvider.overrideWithValue(notificationService),
    ],
  );
}

class _FakeReminderSettingsRepository implements ReminderSettingsRepository {
  ReminderSettings settings = ReminderSettings.defaults;
  final savedSettings = <ReminderSettings>[];

  @override
  Future<ReminderSettings> load() async {
    return settings;
  }

  @override
  Future<void> save(ReminderSettings settings) async {
    this.settings = settings;
    savedSettings.add(settings);
  }
}

class _FakePostureSessionRepository implements PostureSessionRepository {
  @override
  Future<void> endCurrent({DateTime? now}) async {}

  @override
  Future<List<PostureSession>> loadAll() async {
    return const [];
  }

  @override
  Future<List<PostureSession>> loadToday({DateTime? now}) async {
    return const [];
  }

  @override
  Future<List<PostureSession>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async {
    return const [];
  }

  @override
  Future<PostureSession?> loadOpenSession() async {
    return PostureSession(
      id: 1,
      type: PostureType.sitting,
      startedAt: DateTime(2026, 6, 6, 9),
    );
  }

  @override
  Future<PostureSession> switchTo({
    required PostureType type,
    DateTime? now,
  }) async {
    return PostureSession(
      id: 2,
      type: type,
      startedAt: now ?? DateTime(2026, 6, 6, 10),
    );
  }
}

class _FakeNotificationService extends NotificationService {
  final scheduledSettings = <_ScheduledSettings>[];

  @override
  Future<void> scheduleNextReminders({
    required bool enabled,
    required int sittingIntervalMinutes,
    required int standingIntervalMinutes,
    PostureType? currentPosture,
  }) async {
    scheduledSettings.add(
      _ScheduledSettings(
        enabled: enabled,
        sittingIntervalMinutes: sittingIntervalMinutes,
        standingIntervalMinutes: standingIntervalMinutes,
      ),
    );
  }
}

class _ScheduledSettings {
  const _ScheduledSettings({
    required this.enabled,
    required this.sittingIntervalMinutes,
    required this.standingIntervalMinutes,
  });

  final bool enabled;
  final int sittingIntervalMinutes;
  final int standingIntervalMinutes;
}
