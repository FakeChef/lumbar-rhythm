import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../domain/recovery_milestone.dart';

final recoveryMilestoneRepositoryProvider =
    Provider<RecoveryMilestoneRepository>((ref) {
  return SqfliteRecoveryMilestoneRepository(ref.watch(localDatabaseProvider));
});

abstract class RecoveryMilestoneRepository {
  Future<List<RecoveryMilestone>> loadMilestones();

  Future<void> addCustom({
    required String title,
    String category,
    DateTime? targetDate,
    String? note,
  });

  Future<void> complete(int id, {String? note});

  Future<void> postpone(int id, DateTime targetDate, {String? note});
}

class SqfliteRecoveryMilestoneRepository
    implements RecoveryMilestoneRepository {
  const SqfliteRecoveryMilestoneRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<List<RecoveryMilestone>> loadMilestones() async {
    final rows = await _database.readRecoveryMilestones();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> addCustom({
    required String title,
    String category = '自定义',
    DateTime? targetDate,
    String? note,
  }) async {
    final rows = await _database.readRecoveryMilestones();
    await _database.insertRecoveryMilestone(
      title: title.trim().isEmpty ? '自定义康复节点' : title.trim(),
      category: category,
      plannedDayOffset: null,
      targetDate: targetDate,
      status: 'planned',
      note: _cleanOptional(note),
      sortOrder: rows.length + 1,
    );
  }

  @override
  Future<void> complete(int id, {String? note}) {
    return _database.updateRecoveryMilestone(
      id: id,
      status: 'completed',
      targetDate: null,
      completedAt: DateTime.now(),
      note: _cleanOptional(note),
    );
  }

  @override
  Future<void> postpone(int id, DateTime targetDate, {String? note}) {
    return _database.updateRecoveryMilestone(
      id: id,
      status: 'planned',
      targetDate: targetDate,
      completedAt: null,
      note: _cleanOptional(note),
    );
  }

  RecoveryMilestone _fromRow(Map<String, Object?> row) {
    return RecoveryMilestone(
      id: row['id'] as int,
      title: row['title'] as String,
      category: row['category'] as String,
      plannedDayOffset: row['planned_day_offset'] as int?,
      targetDate: _parseOptionalDate(row['target_date'] as String?),
      completedAt: _parseOptionalDate(row['completed_at'] as String?),
      status: row['status'] as String,
      note: row['note'] as String?,
      isBuiltin: (row['is_builtin'] as int) == 1,
      sortOrder: row['sort_order'] as int,
    );
  }

  DateTime? _parseOptionalDate(String? value) {
    return value == null ? null : DateTime.tryParse(value);
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
