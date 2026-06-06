import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_summary.dart';
import 'package:lumbar_rhythm/features/reports/domain/daily_report.dart';

void main() {
  test('summarizes posture sessions and rehab logs for reports', () {
    final now = DateTime(2026, 6, 6, 12);
    const walking = RehabAction(
      id: 1,
      name: '步行',
      defaultUnit: '分钟',
      guidance: '按自己舒适节奏记录一次步行。',
    );
    const breathing = RehabAction(
      id: 3,
      name: '腹式呼吸',
      defaultUnit: '次',
      guidance: '选择舒适姿势，放慢呼吸并记录完成量。',
    );
    final report = DailyReport(
      postureSummary: PostureSummary(
        now: now,
        sessions: [
          PostureSession(
            id: 1,
            type: PostureType.sitting,
            startedAt: DateTime(2026, 6, 6, 8),
            endedAt: DateTime(2026, 6, 6, 9),
          ),
          PostureSession(
            id: 2,
            type: PostureType.standing,
            startedAt: DateTime(2026, 6, 6, 9),
            endedAt: DateTime(2026, 6, 6, 9, 30),
          ),
        ],
      ),
      recentPostureSummary: PostureSummary(sessions: const [], now: now),
      rehabActions: [walking, breathing],
      rehabLogs: [
        RehabLog(
          id: 1,
          actionId: walking.id,
          amount: '10',
          unit: '分钟',
          reaction: RehabReaction.moreComfortable,
          createdAt: DateTime(2026, 6, 6, 10),
        ),
        RehabLog(
          id: 2,
          actionId: breathing.id,
          amount: '1',
          unit: '次',
          reaction: RehabReaction.muchWorse,
          createdAt: DateTime(2026, 6, 6, 11),
        ),
      ],
    );

    expect(report.postureSummary.sittingTotal, const Duration(hours: 1));
    expect(report.postureSummary.standingTotal, const Duration(minutes: 30));
    expect(report.postureSummary.switchCount, 1);
    expect(report.rehabSummary.totalCount, 2);
    expect(report.rehabSummary.totalAmountForActionNamed('步行'), 10);
    expect(report.rehabSummary.reactionCount(RehabReaction.muchWorse), 1);
    expect(report.rehabSummary.mostCompletedAction()?.name, '步行');
    expect(report.rehabSummary.observationActionNames(), '腹式呼吸');
  });
}
