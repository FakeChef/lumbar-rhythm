import '../../records/domain/activity_record.dart';

class DailyReport {
  const DailyReport({
    required this.records,
    this.recentRecords = const [],
  });

  final List<ActivityRecord> records;
  final List<ActivityRecord> recentRecords;

  int get totalCount => records.length;

  int get recentTotalCount => recentRecords.length;

  ActivityRecord? get latestRecord {
    if (records.isEmpty) {
      return null;
    }

    return records.first;
  }

  int countFor(ActivityRecordType type) {
    return records.where((record) => record.type == type).length;
  }

  int recentCountFor(ActivityRecordType type) {
    return recentRecords.where((record) => record.type == type).length;
  }

  int activeDaysCount() {
    return recentRecords
        .map((record) {
          final createdAt = record.createdAt;
          return DateTime(createdAt.year, createdAt.month, createdAt.day);
        })
        .toSet()
        .length;
  }
}
