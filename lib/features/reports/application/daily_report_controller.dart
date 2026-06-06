import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/data/rehab_repository.dart';
import '../../posture/data/posture_session_repository.dart';
import '../../posture/domain/posture_summary.dart';
import '../../records/data/activity_record_repository.dart';
import '../domain/daily_report.dart';

final dailyReportControllerProvider =
    AsyncNotifierProvider<DailyReportController, DailyReport>(
  DailyReportController.new,
);

class DailyReportController extends AsyncNotifier<DailyReport> {
  @override
  Future<DailyReport> build() async {
    final repository = ref.watch(activityRecordRepositoryProvider);
    final rehabRepository = ref.watch(rehabRepositoryProvider);
    final postureRepository = ref.watch(postureSessionRepositoryProvider);
    final now = DateTime.now();
    final records = await repository.loadToday();
    final recentRecords = await repository.loadRecentDays(days: 7);
    final rehabLogs = await rehabRepository.loadToday();
    final recentRehabLogs = await rehabRepository.loadRecentDays(days: 7);
    final postureSessions = await postureRepository.loadToday(now: now);
    final recentPostureSessions = await postureRepository.loadRecentDays(
      days: 7,
      now: now,
    );

    return DailyReport(
      records: records,
      recentRecords: recentRecords,
      rehabLogs: rehabLogs,
      recentRehabLogs: recentRehabLogs,
      postureSummary: PostureSummary(sessions: postureSessions, now: now),
      recentPostureSummary: PostureSummary(
        sessions: recentPostureSessions,
        now: now,
      ),
    );
  }
}
