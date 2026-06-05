enum ActivityRecordType {
  sitting,
  standing,
  symptom,
  stretch,
}

extension ActivityRecordTypeLabel on ActivityRecordType {
  String get storageValue => name;

  String get label {
    return switch (this) {
      ActivityRecordType.sitting => '久坐',
      ActivityRecordType.standing => '久站',
      ActivityRecordType.symptom => '症状记录',
      ActivityRecordType.stretch => '活动/拉伸',
    };
  }

  String get description {
    return switch (this) {
      ActivityRecordType.sitting => '记录一次较长时间坐姿',
      ActivityRecordType.standing => '记录一次较长时间站立',
      ActivityRecordType.symptom => '仅记录主观感受，不做诊断判断',
      ActivityRecordType.stretch => '记录一次活动、走动或拉伸',
    };
  }
}

class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.type,
    required this.createdAt,
    this.note,
  });

  final int id;
  final ActivityRecordType type;
  final DateTime createdAt;
  final String? note;
}
