class RecoveryMilestone {
  const RecoveryMilestone({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.isBuiltin,
    required this.sortOrder,
    this.plannedDayOffset,
    this.targetDate,
    this.completedAt,
    this.note,
  });

  final int id;
  final String title;
  final String category;
  final int? plannedDayOffset;
  final DateTime? targetDate;
  final DateTime? completedAt;
  final String status;
  final String? note;
  final bool isBuiltin;
  final int sortOrder;

  bool get isCompleted => status == 'completed';
}
