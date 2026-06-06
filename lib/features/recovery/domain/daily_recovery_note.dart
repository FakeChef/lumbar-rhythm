enum OverallFeeling {
  better,
  same,
  slightlyWorse,
}

extension OverallFeelingLabel on OverallFeeling {
  String get storageValue => name;

  String get label {
    return switch (this) {
      OverallFeeling.better => '更好',
      OverallFeeling.same => '差不多',
      OverallFeeling.slightlyWorse => '有点加重',
    };
  }
}

class DailyRecoveryNote {
  const DailyRecoveryNote({
    required this.date,
    required this.overallFeeling,
    required this.backPainScore,
    required this.legSymptomScore,
    required this.fatigueScore,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.note,
  });

  final DateTime date;
  final OverallFeeling overallFeeling;
  final int backPainScore;
  final int legSymptomScore;
  final int fatigueScore;
  final List<String> tags;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}
