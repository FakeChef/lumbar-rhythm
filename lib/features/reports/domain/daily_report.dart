import '../../actions/domain/action_item.dart';
import '../../posture/domain/posture_summary.dart';

class DailyReport {
  const DailyReport({
    required this.postureSummary,
    required this.recentPostureSummary,
    this.rehabLogs = const [],
    this.recentRehabLogs = const [],
    this.rehabActions = const [],
  });

  final List<RehabLog> rehabLogs;
  final List<RehabLog> recentRehabLogs;
  final List<RehabAction> rehabActions;
  final PostureSummary postureSummary;
  final PostureSummary recentPostureSummary;

  RehabSummary get rehabSummary {
    return RehabSummary(logs: rehabLogs, actions: rehabActions);
  }

  RehabSummary get recentRehabSummary {
    return RehabSummary(logs: recentRehabLogs, actions: rehabActions);
  }
}
