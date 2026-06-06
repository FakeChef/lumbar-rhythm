import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
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

  test('summarizes rehab logs by reaction', () {
    final report = DailyReport(
      records: const [],
      rehabLogs: [
        RehabLog(
          id: 1,
          actionId: 1,
          amount: '10',
          unit: '分钟',
          reaction: RehabReaction.moreComfortable,
          createdAt: DateTime(2026, 6, 6, 9),
        ),
        RehabLog(
          id: 2,
          actionId: 2,
          amount: '1',
          unit: '次',
          reaction: RehabReaction.muchWorse,
          createdAt: DateTime(2026, 6, 6, 10),
        ),
      ],
      recentRehabLogs: [
        RehabLog(
          id: 3,
          actionId: 3,
          amount: '5',
          unit: '次',
          reaction: RehabReaction.noChange,
          createdAt: DateTime(2026, 6, 5, 9),
        ),
      ],
    );

    expect(report.rehabSummary.totalCount, 2);
    expect(report.rehabSummary.reactionCount(RehabReaction.muchWorse), 1);
    expect(report.recentRehabSummary.totalCount, 1);
    expect(report.recentRehabSummary.reactionCount(RehabReaction.noChange), 1);
  });
}
