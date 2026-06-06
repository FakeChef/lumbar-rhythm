enum PostureType {
  sitting,
  standing,
  walking,
  resting,
}

extension PostureTypeLabel on PostureType {
  String get storageValue => name;

  String get label {
    return switch (this) {
      PostureType.sitting => '我在坐',
      PostureType.standing => '我在站',
      PostureType.walking => '我在走',
      PostureType.resting => '我在休息',
    };
  }

  String get shortLabel {
    return switch (this) {
      PostureType.sitting => '坐',
      PostureType.standing => '站',
      PostureType.walking => '走',
      PostureType.resting => '休息',
    };
  }
}

class PostureSession {
  const PostureSession({
    required this.id,
    required this.type,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  final int id;
  final PostureType type;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  bool get isOpen => endedAt == null;

  Duration durationAt(DateTime now) {
    final end = endedAt ?? now;
    final duration = end.difference(startedAt);
    return duration.isNegative ? Duration.zero : duration;
  }
}
