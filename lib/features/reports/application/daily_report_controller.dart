import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final allRehabLogs = await rehabRepository.loadAllLogs();
    final allPostureSessions = await postureRepository.loadAll();
    final recentRange = (
      start: DateTime(now.year, now.month, now.day).subtract(
        const Duration(days: 6),
      ),
      end: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    );
    final rehabLogs = allRehabLogs.where((log) {
      return _isWithin(log.createdAt, range);
    }).toList();
    final recentRehabLogs = allRehabLogs.where((log) {
      return _isWithin(log.createdAt, recentRange);
    }).toList();
    final postureSessions = allPostureSessions.where((session) {
      return _isWithin(session.startedAt, range);
    }).toList();
    final recentPostureSessions = allPostureSessions.where((session) {
      return _isWithin(session.startedAt, recentRange);
    }).toList();
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
      recentPostureSummary: _postureSummary(
        sessions: recentPostureSessions,
        now: now,
        settings: reminderSettings,
      ),
    );
  }

  ({DateTime start, DateTime end}) _rangeFor(
    ReportPeriod period,
    DateTime now,
  ) {
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
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        ),
    };
  }

  bool _isWithin(DateTime value, ({DateTime start, DateTime end}) range) {
    return !value.isBefore(range.start) && value.isBefore(range.end);
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
