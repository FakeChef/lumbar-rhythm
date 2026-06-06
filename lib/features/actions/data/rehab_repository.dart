import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../domain/action_item.dart';

final rehabRepositoryProvider = Provider<RehabRepository>((ref) {
  return SqfliteRehabRepository(ref.watch(localDatabaseProvider));
});

abstract class RehabRepository {
  Future<List<RehabAction>> loadActions();

  Future<RehabLog> addLog({
    required RehabAction action,
    required String amount,
    required String unit,
    required RehabReaction reaction,
    String? symptomTag,
    List<String> symptomTags = const [],
    String source = 'manual',
    String? note,
    DateTime? createdAt,
  });

  Future<List<RehabLog>> loadToday({DateTime? now});

  Future<List<RehabLog>> loadRecentDays({
    required int days,
    DateTime? now,
  });

  Future<List<RehabLog>> loadAllLogs();
}

class SqfliteRehabRepository implements RehabRepository {
  const SqfliteRehabRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<List<RehabAction>> loadActions() async {
    final rows = await _database.readRehabActions();
    return rows.map(_actionFromRow).toList();
  }

  @override
  Future<RehabLog> addLog({
    required RehabAction action,
    required String amount,
    required String unit,
    required RehabReaction reaction,
    String? symptomTag,
    List<String> symptomTags = const [],
    String source = 'manual',
    String? note,
    DateTime? createdAt,
  }) async {
    final savedAt = createdAt ?? DateTime.now();
    final cleanedAmount = amount.trim().isEmpty ? '1' : amount.trim();
    final cleanedUnit = unit.trim().isEmpty ? action.defaultUnit : unit.trim();
    final cleanedSymptom = _cleanOptional(symptomTag);
    final cleanedTags = symptomTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final amountValue = double.tryParse(cleanedAmount) ?? 0;
    final cleanedNote = _cleanOptional(note);
    final id = await _database.insertRehabLog(
      actionId: action.id,
      amount: cleanedAmount,
      amountValue: amountValue,
      unit: cleanedUnit,
      reaction: reaction.storageValue,
      symptomTag: cleanedSymptom,
      symptomTags: cleanedTags.isEmpty ? cleanedSymptom : cleanedTags.join(','),
      source: source,
      note: cleanedNote,
      createdAt: savedAt,
    );

    return RehabLog(
      id: id,
      actionId: action.id,
      amount: cleanedAmount,
      amountValue: amountValue,
      unit: cleanedUnit,
      reaction: reaction,
      source: source,
      symptomTag: cleanedSymptom,
      symptomTags: cleanedTags.isEmpty
          ? [if (cleanedSymptom != null) cleanedSymptom]
          : cleanedTags,
      note: cleanedNote,
      createdAt: savedAt,
    );
  }

  @override
  Future<List<RehabLog>> loadToday({DateTime? now}) async {
    final anchor = now ?? DateTime.now();
    final start = DateTime(anchor.year, anchor.month, anchor.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _database.readRehabLogsCreatedBetween(
      start: start,
      end: end,
    );
    return rows.map(_logFromRow).toList();
  }

  @override
  Future<List<RehabLog>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final todayStart = DateTime(anchor.year, anchor.month, anchor.day);
    final start = todayStart.subtract(Duration(days: days - 1));
    final end = todayStart.add(const Duration(days: 1));
    final rows = await _database.readRehabLogsCreatedBetween(
      start: start,
      end: end,
    );
    return rows.map(_logFromRow).toList();
  }

  @override
  Future<List<RehabLog>> loadAllLogs() async {
    final rows = await _database.readAllRehabLogs();
    return rows.map(_logFromRow).toList();
  }

  RehabAction _actionFromRow(Map<String, Object?> row) {
    return RehabAction(
      id: row['id'] as int,
      name: row['name'] as String,
      defaultUnit: row['default_unit'] as String,
      guidance: row['guidance'] as String,
    );
  }

  RehabLog _logFromRow(Map<String, Object?> row) {
    final reactionValue = row['reaction'] as String;
    return RehabLog(
      id: row['id'] as int,
      actionId: row['action_id'] as int,
      amount: row['amount'] as String,
      amountValue: (row['amount_value'] as num?)?.toDouble() ??
          (double.tryParse(row['amount'] as String) ?? 0),
      unit: row['unit'] as String,
      reaction: RehabReaction.values.firstWhere(
        (reaction) => reaction.storageValue == reactionValue,
        orElse: () => RehabReaction.noChange,
      ),
      source: (row['source'] as String?) ?? 'manual',
      symptomTag: row['symptom_tag'] as String?,
      symptomTags: _tagsFromRow(row),
      note: row['note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  List<String> _tagsFromRow(Map<String, Object?> row) {
    final tags = row['symptom_tags'] as String?;
    if (tags == null || tags.trim().isEmpty) {
      final legacy = row['symptom_tag'] as String?;
      return legacy == null || legacy.trim().isEmpty ? const [] : [legacy];
    }
    return tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
}
