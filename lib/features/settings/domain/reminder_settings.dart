enum ReminderMode {
  soft,
  vibration,
  alarm,
}

extension ReminderModeLabel on ReminderMode {
  String get storageValue => name;

  String get label {
    return switch (this) {
      ReminderMode.soft => '轻柔通知',
      ReminderMode.vibration => '震动提醒',
      ReminderMode.alarm => '响铃提醒',
    };
  }
}

class ReminderSettings {
  const ReminderSettings({
    required this.remindersEnabled,
    required this.sittingIntervalMinutes,
    required this.standingIntervalMinutes,
    this.walkingIntervalMinutes = 10,
    this.reminderMode = ReminderMode.soft,
    this.daytimeLoopEnabled = true,
    this.daytimeStartMinutes = 9 * 60,
    this.daytimeEndMinutes = 18 * 60,
    this.daytimeSittingMinutes = 30,
    this.daytimeWalkingMinutes = 3,
  });

  static const minIntervalMinutes = 15;
  static const maxIntervalMinutes = 120;
  static const intervalStepMinutes = 15;
  static const testingIntervalMinutes = 1;

  static const defaults = ReminderSettings(
    remindersEnabled: true,
    sittingIntervalMinutes: 45,
    standingIntervalMinutes: 30,
    walkingIntervalMinutes: 10,
    reminderMode: ReminderMode.soft,
    daytimeLoopEnabled: true,
    daytimeStartMinutes: 9 * 60,
    daytimeEndMinutes: 18 * 60,
    daytimeSittingMinutes: 30,
    daytimeWalkingMinutes: 3,
  );

  final bool remindersEnabled;
  final int sittingIntervalMinutes;
  final int standingIntervalMinutes;
  final int walkingIntervalMinutes;
  final ReminderMode reminderMode;
  final bool daytimeLoopEnabled;
  final int daytimeStartMinutes;
  final int daytimeEndMinutes;
  final int daytimeSittingMinutes;
  final int daytimeWalkingMinutes;

  ReminderSettings copyWith({
    bool? remindersEnabled,
    int? sittingIntervalMinutes,
    int? standingIntervalMinutes,
    int? walkingIntervalMinutes,
    ReminderMode? reminderMode,
    bool? daytimeLoopEnabled,
    int? daytimeStartMinutes,
    int? daytimeEndMinutes,
    int? daytimeSittingMinutes,
    int? daytimeWalkingMinutes,
  }) {
    return ReminderSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      sittingIntervalMinutes: _normalizeInterval(
          sittingIntervalMinutes ?? this.sittingIntervalMinutes),
      standingIntervalMinutes: _normalizeInterval(
          standingIntervalMinutes ?? this.standingIntervalMinutes),
      walkingIntervalMinutes: _normalizeSmallInterval(
          walkingIntervalMinutes ?? this.walkingIntervalMinutes),
      reminderMode: reminderMode ?? this.reminderMode,
      daytimeLoopEnabled: daytimeLoopEnabled ?? this.daytimeLoopEnabled,
      daytimeStartMinutes: _normalizeClockMinutes(
          daytimeStartMinutes ?? this.daytimeStartMinutes),
      daytimeEndMinutes:
          _normalizeClockMinutes(daytimeEndMinutes ?? this.daytimeEndMinutes),
      daytimeSittingMinutes: _normalizeSmallInterval(
          daytimeSittingMinutes ?? this.daytimeSittingMinutes),
      daytimeWalkingMinutes: _normalizeSmallInterval(
          daytimeWalkingMinutes ?? this.daytimeWalkingMinutes),
    );
  }

  static ReminderMode parseMode(String? value) {
    return ReminderMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => ReminderSettings.defaults.reminderMode,
    );
  }

  static int _normalizeInterval(int value) {
    if (value == testingIntervalMinutes) {
      return testingIntervalMinutes;
    }
    final clamped = value.clamp(minIntervalMinutes, maxIntervalMinutes);
    return (clamped / intervalStepMinutes).round() * intervalStepMinutes;
  }

  static int _normalizeSmallInterval(int value) {
    return value.clamp(1, maxIntervalMinutes).toInt();
  }

  static int _normalizeClockMinutes(int value) {
    return value.clamp(0, 23 * 60 + 59).toInt();
  }
}
