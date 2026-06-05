import '../../records/domain/activity_record.dart';

class DailyReport {
  const DailyReport({
    required this.records,
  });

  final List<ActivityRecord> records;

  int get totalCount => records.length;

  ActivityRecord? get latestRecord {
    if (records.isEmpty) {
      return null;
    }

    return records.first;
  }

  int countFor(ActivityRecordType type) {
    return records.where((record) => record.type == type).length;
  }
}
