import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../actions/data/rehab_repository.dart';
import '../../milestones/data/recovery_milestone_repository.dart';
import '../../posture/data/posture_session_repository.dart';
import '../../posture/domain/posture_session.dart';
import '../../posture/domain/posture_summary.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../settings/data/reminder_settings_repository.dart';
import '../../settings/domain/reminder_settings.dart';
import '../domain/daily_report.dart';

enum ReportPeriod {
  day,
  week,
  month,
}

extension ReportPeriodLabel on ReportPeriod {
  String get label {
    return switch (this) {
      ReportPeriod.day => '日',
      ReportPeriod.week => '周',
      ReportPeriod.month => '月',
    };
  }
}

final reportPeriodProvider = StateProvider<ReportPeriod>((ref) {
  return ReportPeriod.day;
});

final dailyReportControllerProvider =
    AsyncNotifierProvider<DailyReportController, DailyReport>(
  DailyReportController.new,
);

class DailyReportController extends AsyncNotifier<DailyReport> {
  @override
  Future<DailyReport> build() async {
    ref.watch(appDataRefreshProvider);
    final rehabRepository = ref.watch(rehabRepositoryProvider);
    final postureRepository = ref.watch(postureSessionRepositoryProvider);
    final recoveryRepository = ref.watch(recoveryRepositoryProvider);
    final milestoneRepository = ref.watch(recoveryMilestoneRepositoryProvider);
    final reminderSettingsRepository =
        ref.watch(reminderSettingsRepositoryProvider);
    final period = ref.watch(reportPeriodProvider);
    final now = DateTime.now();
    final rehabActions = await rehabRepository.loadActions();
    final reminderSettings = await reminderSettingsRepository.load();
    final range = _rangeFor(period, now);
    final recentRange = (
      start: DateTime(now.year, now.month, now.day).subtract(
        const Duration(days: 6),
      ),
      end: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    );
    final rehabLogs = await rehabRepository.loadLogsBetween(
      start: range.start,
      end: range.end,
    );
    final recentRehabLogs = await rehabRepository.loadLogsBetween(
      start: recentRange.start,
      end: recentRange.end,
    );
    final postureSessions = await postureRepository.loadSessionsBetween(
      start: range.start,
      end: range.end,
    );
    final recentPostureSessions = await postureRepository.loadSessionsBetween(
      start: recentRange.start,
      end: recentRange.end,
    );
    final dailyNotes = await recoveryRepository.loadNotesBetween(
      start: range.start,
      end: range.end,
    );
    final recentDailyNotes = await recoveryRepository.loadNotesBetween(
      start: recentRange.start,
      end: recentRange.end,
    );

    return DailyReport(
      profile: await recoveryRepository.loadProfile(),
      rehabLogs: rehabLogs,
      recentRehabLogs: recentRehabLogs,
      rehabActions: rehabActions,
      dailyNotes: dailyNotes,
      recentDailyNotes: recentDailyNotes,
      milestones: await milestoneRepository.loadMilestones(),
      reminderSettings: reminderSettings,
      postureSummary: _postureSummary(
        sessions: postureSessions,
        now: now,
        settings: reminderSettings,
      ),
      recentPostureSummary: PostureSummary(
        sessions: recentPostureSessions,
        now: now,
        sittingThreshold:
            Duration(minutes: reminderSettings.sittingIntervalMinutes),
        standingThreshold:
            Duration(minutes: reminderSettings.standingIntervalMinutes),
      ),
    );
  }

  ({DateTime start, DateTime end}) _rangeFor(
      ReportPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      ReportPeriod.day => (
          start: today,
          end: today.add(const Duration(days: 1))
        ),
      ReportPeriod.week => (
          start: today.subtract(const Duration(days: 6)),
          end: today.add(const Duration(days: 1)),
        ),
      ReportPeriod.month => (
          start: today.subtract(const Duration(days: 29)),
          end: today.add(const Duration(days: 1)),
        ),
    };
  }

  PostureSummary _postureSummary({
    required List<PostureSession> sessions,
    required DateTime now,
    required ReminderSettings settings,
  }) {
    return PostureSummary(
      sessions: sessions,
      now: now,
      sittingThreshold: Duration(minutes: settings.sittingIntervalMinutes),
      standingThreshold: Duration(minutes: settings.standingIntervalMinutes),
    );
  }
}
