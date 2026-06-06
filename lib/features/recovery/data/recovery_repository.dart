import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../domain/daily_recovery_note.dart';
import '../domain/recovery_profile.dart';

final recoveryRepositoryProvider = Provider<RecoveryRepository>((ref) {
  return SqfliteRecoveryRepository(ref.watch(localDatabaseProvider));
});

abstract class RecoveryRepository {
  Future<RecoveryProfile?> loadProfile();

  Future<void> saveProfile({
    DateTime? surgeryDate,
    String? surgeryType,
    String? mainGoal,
  });

  Future<DailyRecoveryNote?> loadNote(DateTime date);

  Future<void> saveNote({
    required DateTime date,
    required OverallFeeling overallFeeling,
    required int backPainScore,
    required int legSymptomScore,
    required int fatigueScore,
    String? note,
  });

  Future<List<DailyRecoveryNote>> loadNotesBetween({
    required DateTime start,
    required DateTime end,
  });
}

class SqfliteRecoveryRepository implements RecoveryRepository {
  const SqfliteRecoveryRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<RecoveryProfile?> loadProfile() async {
    final row = await _database.readRecoveryProfile();
    return row == null ? null : _profileFromRow(row);
  }

  @override
  Future<void> saveProfile({
    DateTime? surgeryDate,
    String? surgeryType,
    String? mainGoal,
  }) {
    return _database.upsertRecoveryProfile(
      surgeryDate: surgeryDate,
      surgeryType: _cleanOptional(surgeryType),
      mainGoal: _cleanOptional(mainGoal),
      now: DateTime.now(),
    );
  }

  @override
  Future<DailyRecoveryNote?> loadNote(DateTime date) async {
    final row = await _database.readDailyRecoveryNote(date);
    return row == null ? null : _noteFromRow(row);
  }

  @override
  Future<void> saveNote({
    required DateTime date,
    required OverallFeeling overallFeeling,
    required int backPainScore,
    required int legSymptomScore,
    required int fatigueScore,
    String? note,
  }) {
    return _database.upsertDailyRecoveryNote(
      date: date,
      overallFeeling: overallFeeling.storageValue,
      backPainScore: backPainScore.clamp(0, 10),
      legSymptomScore: legSymptomScore.clamp(0, 10),
      fatigueScore: fatigueScore.clamp(0, 10),
      note: _cleanOptional(note),
      now: DateTime.now(),
    );
  }

  @override
  Future<List<DailyRecoveryNote>> loadNotesBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _database.readDailyRecoveryNotesBetween(
      start: start,
      end: end,
    );
    return rows.map(_noteFromRow).toList();
  }

  RecoveryProfile _profileFromRow(Map<String, Object?> row) {
    return RecoveryProfile(
      id: row['id'] as int,
      surgeryDate: _parseOptionalDate(row['surgery_date'] as String?),
      surgeryType: row['surgery_type'] as String?,
      mainGoal: row['main_goal'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  DailyRecoveryNote _noteFromRow(Map<String, Object?> row) {
    final feelingValue = row['overall_feeling'] as String;
    return DailyRecoveryNote(
      date: DateTime.parse(row['date'] as String),
      overallFeeling: OverallFeeling.values.firstWhere(
        (feeling) => feeling.storageValue == feelingValue,
        orElse: () => OverallFeeling.same,
      ),
      backPainScore: row['back_pain_score'] as int,
      legSymptomScore: row['leg_symptom_score'] as int,
      fatigueScore: row['fatigue_score'] as int,
      note: row['note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
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
