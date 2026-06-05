import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../domain/activity_record.dart';

final activityRecordRepositoryProvider =
    Provider<ActivityRecordRepository>((ref) {
  return SqfliteActivityRecordRepository(ref.watch(localDatabaseProvider));
});

abstract class ActivityRecordRepository {
  Future<ActivityRecord> add({
    required ActivityRecordType type,
    String? note,
    DateTime? createdAt,
  });

  Future<List<ActivityRecord>> loadToday({DateTime? now});
}

class SqfliteActivityRecordRepository implements ActivityRecordRepository {
  const SqfliteActivityRecordRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<ActivityRecord> add({
    required ActivityRecordType type,
    String? note,
    DateTime? createdAt,
  }) async {
    final savedAt = createdAt ?? DateTime.now();
    final cleanedNote = note?.trim();
    final id = await _database.insertRecord(
      type: type.storageValue,
      note: cleanedNote == null || cleanedNote.isEmpty ? null : cleanedNote,
      createdAt: savedAt,
    );

    return ActivityRecord(
      id: id,
      type: type,
      note: cleanedNote == null || cleanedNote.isEmpty ? null : cleanedNote,
      createdAt: savedAt,
    );
  }

  @override
  Future<List<ActivityRecord>> loadToday({DateTime? now}) async {
    final anchor = now ?? DateTime.now();
    final start = DateTime(anchor.year, anchor.month, anchor.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _database.readRecordsCreatedBetween(
      start: start,
      end: end,
    );

    return rows.map(_fromRow).toList();
  }

  ActivityRecord _fromRow(Map<String, Object?> row) {
    final typeValue = row['type'] as String;

    return ActivityRecord(
      id: row['id'] as int,
      type: ActivityRecordType.values.firstWhere(
        (type) => type.storageValue == typeValue,
        orElse: () => ActivityRecordType.symptom,
      ),
      note: row['note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
