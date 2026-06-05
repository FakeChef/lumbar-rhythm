class ReminderSettings {
  const ReminderSettings({
    required this.remindersEnabled,
    required this.sittingIntervalMinutes,
    required this.standingIntervalMinutes,
  });

  static const minIntervalMinutes = 15;
  static const maxIntervalMinutes = 120;
  static const intervalStepMinutes = 15;

  static const defaults = ReminderSettings(
    remindersEnabled: true,
    sittingIntervalMinutes: 45,
    standingIntervalMinutes: 30,
  );

  final bool remindersEnabled;
  final int sittingIntervalMinutes;
  final int standingIntervalMinutes;

  ReminderSettings copyWith({
    bool? remindersEnabled,
    int? sittingIntervalMinutes,
    int? standingIntervalMinutes,
  }) {
    return ReminderSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      sittingIntervalMinutes: _normalizeInterval(
          sittingIntervalMinutes ?? this.sittingIntervalMinutes),
      standingIntervalMinutes: _normalizeInterval(
          standingIntervalMinutes ?? this.standingIntervalMinutes),
    );
  }

  static int _normalizeInterval(int value) {
    final clamped = value.clamp(minIntervalMinutes, maxIntervalMinutes);
    return (clamped / intervalStepMinutes).round() * intervalStepMinutes;
  }
}
