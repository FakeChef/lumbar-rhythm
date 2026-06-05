import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final container = _createContainer(repository);
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
  });
}

ProviderContainer _createContainer(ReminderSettingsRepository repository) {
  return ProviderContainer(
    overrides: [
      reminderSettingsRepositoryProvider.overrideWithValue(repository),
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
