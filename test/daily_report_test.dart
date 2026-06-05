import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/records/domain/activity_record.dart';
import 'package:lumbar_rhythm/features/reports/domain/daily_report.dart';

void main() {
  test('counts records by type', () {
    final report = DailyReport(
      records: [
        ActivityRecord(
          id: 1,
          type: ActivityRecordType.sitting,
          createdAt: DateTime(2026, 6, 5, 9),
        ),
        ActivityRecord(
          id: 2,
          type: ActivityRecordType.sitting,
          createdAt: DateTime(2026, 6, 5, 10),
        ),
        ActivityRecord(
          id: 3,
          type: ActivityRecordType.stretch,
          createdAt: DateTime(2026, 6, 5, 11),
        ),
      ],
    );

    expect(report.totalCount, 3);
    expect(report.countFor(ActivityRecordType.sitting), 2);
    expect(report.countFor(ActivityRecordType.stretch), 1);
    expect(report.countFor(ActivityRecordType.symptom), 0);
  });

  test('uses first record as latest because repository sorts descending', () {
    final latest = ActivityRecord(
      id: 2,
      type: ActivityRecordType.standing,
      createdAt: DateTime(2026, 6, 5, 15),
    );
    final report = DailyReport(
      records: [
        latest,
        ActivityRecord(
          id: 1,
          type: ActivityRecordType.sitting,
          createdAt: DateTime(2026, 6, 5, 9),
        ),
      ],
    );

    expect(report.latestRecord, latest);
  });

  test('counts recent records and active days', () {
    final report = DailyReport(
      records: const [],
      recentRecords: [
        ActivityRecord(
          id: 1,
          type: ActivityRecordType.sitting,
          createdAt: DateTime(2026, 6, 5, 9),
        ),
        ActivityRecord(
          id: 2,
          type: ActivityRecordType.stretch,
          createdAt: DateTime(2026, 6, 5, 10),
        ),
        ActivityRecord(
          id: 3,
          type: ActivityRecordType.stretch,
          createdAt: DateTime(2026, 6, 3, 10),
        ),
      ],
    );

    expect(report.recentTotalCount, 3);
    expect(report.recentCountFor(ActivityRecordType.stretch), 2);
    expect(report.activeDaysCount(), 2);
  });
}
