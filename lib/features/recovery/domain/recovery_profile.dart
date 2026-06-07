class RecoveryProfile {
  const RecoveryProfile({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.surgeryDate,
    this.nickname,
    this.surgeryType,
    this.mainSegment,
    this.mainGoal,
  });

  final int id;
  final DateTime? surgeryDate;
  final String? nickname;
  final String? surgeryType;
  final String? mainSegment;
  final String? mainGoal;
  final DateTime createdAt;
  final DateTime updatedAt;

  int? postSurgeryDay(DateTime now) {
    final date = surgeryDate;
    if (date == null) {
      return null;
    }
    final start = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }
}
