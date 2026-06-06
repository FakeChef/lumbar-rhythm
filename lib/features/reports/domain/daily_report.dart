import '../../actions/domain/action_item.dart';
import '../../milestones/domain/recovery_milestone.dart';
import '../../posture/domain/posture_summary.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../recovery/domain/recovery_profile.dart';

class DailyReport {
  const DailyReport({
    required this.postureSummary,
    required this.recentPostureSummary,
    this.profile,
    this.rehabLogs = const [],
    this.recentRehabLogs = const [],
    this.rehabActions = const [],
    this.dailyNotes = const [],
    this.recentDailyNotes = const [],
    this.milestones = const [],
  });

  final RecoveryProfile? profile;
  final List<RehabLog> rehabLogs;
  final List<RehabLog> recentRehabLogs;
  final List<RehabAction> rehabActions;
  final List<DailyRecoveryNote> dailyNotes;
  final List<DailyRecoveryNote> recentDailyNotes;
  final List<RecoveryMilestone> milestones;
  final PostureSummary postureSummary;
  final PostureSummary recentPostureSummary;

  RehabSummary get rehabSummary {
    return RehabSummary(logs: rehabLogs, actions: rehabActions);
  }

  RehabSummary get recentRehabSummary {
    return RehabSummary(logs: recentRehabLogs, actions: rehabActions);
  }

  int? postSurgeryDay(DateTime now) {
    return profile?.postSurgeryDay(now);
  }

  int get recordedDayCount {
    return {
      for (final log in rehabLogs)
        DateTime(log.createdAt.year, log.createdAt.month, log.createdAt.day),
      for (final note in dailyNotes)
        DateTime(note.date.year, note.date.month, note.date.day),
    }.length;
  }

  int get completedMilestoneCount {
    return milestones.where((milestone) => milestone.isCompleted).length;
  }
}
