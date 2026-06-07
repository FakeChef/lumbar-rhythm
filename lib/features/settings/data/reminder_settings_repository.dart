import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../domain/reminder_settings.dart';

final reminderSettingsRepositoryProvider =
    Provider<ReminderSettingsRepository>((ref) {
  return SqfliteReminderSettingsRepository(ref.watch(localDatabaseProvider));
});

abstract class ReminderSettingsRepository {
  Future<ReminderSettings> load();

  Future<void> save(ReminderSettings settings);
}

class SqfliteReminderSettingsRepository implements ReminderSettingsRepository {
  const SqfliteReminderSettingsRepository(this._database);

  static const _remindersEnabledKey = 'reminders_enabled';
  static const _sittingIntervalKey = 'sitting_interval_minutes';
  static const _standingIntervalKey = 'standing_interval_minutes';
  static const _reminderModeKey = 'reminder_mode';

  final LocalDatabase _database;

  @override
  Future<ReminderSettings> load() async {
    final remindersEnabled = await _database.readSetting(_remindersEnabledKey);
    final sittingInterval = await _database.readSetting(_sittingIntervalKey);
    final standingInterval = await _database.readSetting(_standingIntervalKey);
    final reminderMode = await _database.readSetting(_reminderModeKey);

    return ReminderSettings.defaults.copyWith(
      remindersEnabled:
          remindersEnabled == null ? null : remindersEnabled == 'true',
      sittingIntervalMinutes: int.tryParse(sittingInterval ?? ''),
      standingIntervalMinutes: int.tryParse(standingInterval ?? ''),
      reminderMode: ReminderSettings.parseMode(reminderMode),
    );
  }

  @override
  Future<void> save(ReminderSettings settings) async {
    await _database.writeSetting(
      _remindersEnabledKey,
      settings.remindersEnabled.toString(),
    );
    await _database.writeSetting(
      _sittingIntervalKey,
      settings.sittingIntervalMinutes.toString(),
    );
    await _database.writeSetting(
      _standingIntervalKey,
      settings.standingIntervalMinutes.toString(),
    );
    await _database.writeSetting(
      _reminderModeKey,
      settings.reminderMode.storageValue,
    );
  }
}
