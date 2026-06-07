import 'dart:convert';

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
    int? preSymptomScore,
    int? postSymptomScore,
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
    int? preSymptomScore,
    int? postSymptomScore,
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
      symptomTags: _encodeTags(cleanedTags, cleanedSymptom),
      source: source,
      preSymptomScore: _normalizeScore(preSymptomScore),
      postSymptomScore: _normalizeScore(postSymptomScore),
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
      preSymptomScore: _normalizeScore(preSymptomScore),
      postSymptomScore: _normalizeScore(postSymptomScore),
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
    final id = row['id'] as int;
    RehabAction? builtIn;
    for (final action in actionLibrary) {
      if (action.id == id) {
        builtIn = action;
        break;
      }
    }
    return RehabAction(
      id: id,
      activityId: builtIn?.activityId,
      name: row['name'] as String,
      category: builtIn?.category,
      defaultUnit: row['default_unit'] as String,
      optionalUnits: builtIn?.optionalUnits ?? const [],
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
      preSymptomScore: row['pre_symptom_score'] as int?,
      postSymptomScore: row['post_symptom_score'] as int?,
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
    try {
      final decoded = jsonDecode(tags);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    } on FormatException {
      // Older local rows may contain comma-separated tags instead of JSON.
    }
    return tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  String? _encodeTags(List<String> tags, String? legacyTag) {
    final values = tags.isEmpty ? [if (legacyTag != null) legacyTag] : tags;
    return values.isEmpty ? null : jsonEncode(values);
  }

  int? _normalizeScore(int? value) {
    return value?.clamp(0, 10).toInt();
  }
}
