import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/data/rehab_repository.dart';
import '../../posture/data/posture_session_repository.dart';
import '../../posture/domain/posture_summary.dart';
import '../domain/daily_report.dart';

final dailyReportControllerProvider =
    AsyncNotifierProvider<DailyReportController, DailyReport>(
  DailyReportController.new,
);

class DailyReportController extends AsyncNotifier<DailyReport> {
  @override
  Future<DailyReport> build() async {
    final rehabRepository = ref.watch(rehabRepositoryProvider);
    final postureRepository = ref.watch(postureSessionRepositoryProvider);
    final now = DateTime.now();
    final rehabActions = await rehabRepository.loadActions();
    final rehabLogs = await rehabRepository.loadToday();
    final recentRehabLogs = await rehabRepository.loadRecentDays(days: 7);
    final postureSessions = await postureRepository.loadToday(now: now);
    final recentPostureSessions = await postureRepository.loadRecentDays(
      days: 7,
      now: now,
    );

    return DailyReport(
      rehabLogs: rehabLogs,
      recentRehabLogs: recentRehabLogs,
      rehabActions: rehabActions,
      postureSummary: PostureSummary(sessions: postureSessions, now: now),
      recentPostureSummary: PostureSummary(
        sessions: recentPostureSessions,
        now: now,
      ),
    );
  }
}
