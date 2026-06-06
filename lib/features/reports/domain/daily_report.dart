import '../../actions/domain/action_item.dart';
import '../../records/domain/activity_record.dart';

class DailyReport {
  const DailyReport({
    required this.records,
    this.recentRecords = const [],
    this.rehabLogs = const [],
    this.recentRehabLogs = const [],
  });

  final List<ActivityRecord> records;
  final List<ActivityRecord> recentRecords;
  final List<RehabLog> rehabLogs;
  final List<RehabLog> recentRehabLogs;

  int get totalCount => records.length;

  int get recentTotalCount => recentRecords.length;

  RehabSummary get rehabSummary => RehabSummary(logs: rehabLogs);

  RehabSummary get recentRehabSummary => RehabSummary(logs: recentRehabLogs);

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
