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
  static const _walkingIntervalKey = 'walking_interval_minutes';
  static const _reminderModeKey = 'reminder_mode';
  static const _daytimeLoopEnabledKey = 'daytime_loop_enabled';
  static const _daytimeStartMinutesKey = 'daytime_start_minutes';
  static const _daytimeEndMinutesKey = 'daytime_end_minutes';
  static const _daytimeSittingMinutesKey = 'daytime_sitting_minutes';
  static const _daytimeWalkingMinutesKey = 'daytime_walking_minutes';

  final LocalDatabase _database;

  @override
  Future<ReminderSettings> load() async {
    final remindersEnabled = await _database.readSetting(_remindersEnabledKey);
    final sittingInterval = await _database.readSetting(_sittingIntervalKey);
    final standingInterval = await _database.readSetting(_standingIntervalKey);
    final walkingInterval = await _database.readSetting(_walkingIntervalKey);
    final reminderMode = await _database.readSetting(_reminderModeKey);
    final daytimeLoopEnabled =
        await _database.readSetting(_daytimeLoopEnabledKey);
    final daytimeStartMinutes =
        await _database.readSetting(_daytimeStartMinutesKey);
    final daytimeEndMinutes =
        await _database.readSetting(_daytimeEndMinutesKey);
    final daytimeSittingMinutes =
        await _database.readSetting(_daytimeSittingMinutesKey);
    final daytimeWalkingMinutes =
        await _database.readSetting(_daytimeWalkingMinutesKey);

    return ReminderSettings.defaults.copyWith(
      remindersEnabled:
          remindersEnabled == null ? null : remindersEnabled == 'true',
      sittingIntervalMinutes: int.tryParse(sittingInterval ?? ''),
      standingIntervalMinutes: int.tryParse(standingInterval ?? ''),
      walkingIntervalMinutes: int.tryParse(walkingInterval ?? ''),
      reminderMode: ReminderSettings.parseMode(reminderMode),
      daytimeLoopEnabled:
          daytimeLoopEnabled == null ? null : daytimeLoopEnabled == 'true',
      daytimeStartMinutes: int.tryParse(daytimeStartMinutes ?? ''),
      daytimeEndMinutes: int.tryParse(daytimeEndMinutes ?? ''),
      daytimeSittingMinutes: int.tryParse(daytimeSittingMinutes ?? ''),
      daytimeWalkingMinutes: int.tryParse(daytimeWalkingMinutes ?? ''),
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
      _walkingIntervalKey,
      settings.walkingIntervalMinutes.toString(),
    );
    await _database.writeSetting(
      _reminderModeKey,
      settings.reminderMode.storageValue,
    );
    await _database.writeSetting(
      _daytimeLoopEnabledKey,
      settings.daytimeLoopEnabled.toString(),
    );
    await _database.writeSetting(
      _daytimeStartMinutesKey,
      settings.daytimeStartMinutes.toString(),
    );
    await _database.writeSetting(
      _daytimeEndMinutesKey,
      settings.daytimeEndMinutes.toString(),
    );
    await _database.writeSetting(
      _daytimeSittingMinutesKey,
      settings.daytimeSittingMinutes.toString(),
    );
    await _database.writeSetting(
      _daytimeWalkingMinutesKey,
      settings.daytimeWalkingMinutes.toString(),
    );
  }
}
