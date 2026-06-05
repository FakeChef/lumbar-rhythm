import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../records/data/activity_record_repository.dart';
import '../domain/daily_report.dart';

final dailyReportControllerProvider =
    AsyncNotifierProvider<DailyReportController, DailyReport>(
  DailyReportController.new,
);

class DailyReportController extends AsyncNotifier<DailyReport> {
  @override
  Future<DailyReport> build() async {
    final records =
        await ref.watch(activityRecordRepositoryProvider).loadToday();
    return DailyReport(records: records);
  }
}
