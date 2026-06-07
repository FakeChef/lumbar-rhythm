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
    this.reminderMode = ReminderMode.soft,
  });

  static const minIntervalMinutes = 15;
  static const maxIntervalMinutes = 120;
  static const intervalStepMinutes = 15;

  static const defaults = ReminderSettings(
    remindersEnabled: true,
    sittingIntervalMinutes: 45,
    standingIntervalMinutes: 30,
    reminderMode: ReminderMode.soft,
  );

  final bool remindersEnabled;
  final int sittingIntervalMinutes;
  final int standingIntervalMinutes;
  final ReminderMode reminderMode;

  ReminderSettings copyWith({
    bool? remindersEnabled,
    int? sittingIntervalMinutes,
    int? standingIntervalMinutes,
    ReminderMode? reminderMode,
  }) {
    return ReminderSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      sittingIntervalMinutes: _normalizeInterval(
          sittingIntervalMinutes ?? this.sittingIntervalMinutes),
      standingIntervalMinutes: _normalizeInterval(
          standingIntervalMinutes ?? this.standingIntervalMinutes),
      reminderMode: reminderMode ?? this.reminderMode,
    );
  }

  static ReminderMode parseMode(String? value) {
    return ReminderMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => ReminderSettings.defaults.reminderMode,
    );
  }

  static int _normalizeInterval(int value) {
    final clamped = value.clamp(minIntervalMinutes, maxIntervalMinutes);
    return (clamped / intervalStepMinutes).round() * intervalStepMinutes;
  }
}
