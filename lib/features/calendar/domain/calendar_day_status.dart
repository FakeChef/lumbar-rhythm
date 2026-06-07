import '../../actions/domain/action_item.dart';
import '../../milestones/domain/recovery_milestone.dart';
import '../../posture/domain/posture_session.dart';
import '../../posture/domain/posture_summary.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../recovery/domain/recovery_profile.dart';

enum CalendarStatusDot {
  none,
  rehabAction,
  postureStable,
  postureExceeded,
  muchWorse,
  milestoneCompleted,
}

class CalendarDayStatus {
  CalendarDayStatus({
    required DateTime date,
    required this.actions,
    required this.rehabLogs,
    required this.postureSessions,
    this.note,
    this.profile,
    this.milestones = const [],
  }) : date = DateTime(date.year, date.month, date.day);

  final DateTime date;
  final List<RehabAction> actions;
  final List<RehabLog> rehabLogs;
  final List<PostureSession> postureSessions;
  final DailyRecoveryNote? note;
  final RecoveryProfile? profile;
  final List<RecoveryMilestone> milestones;

  bool get hasDailyStatus => note != null;

  bool get hasRehabAction => rehabLogs.isNotEmpty;

  bool get hasPostureRecord => postureSessions.isNotEmpty;

  bool get hasPostureExceeded {
    return postureSessions.any((session) {
      final isSittingOrStanding = session.type == PostureType.sitting ||
          session.type == PostureType.standing;
      return isSittingOrStanding && session.exceededSeconds > 0;
    });
  }

  bool get hasPostureStable => hasPostureRecord && !hasPostureExceeded;

  bool get hasMuchWorse {
    return rehabLogs.any((log) => log.reaction == RehabReaction.muchWorse);
  }

  bool get hasCompletedMilestone {
    return completedMilestones.isNotEmpty;
  }

  List<RecoveryMilestone> get completedMilestones {
    return milestones.where((milestone) {
      final completedAt = milestone.completedAt;
      return milestone.isCompleted &&
          completedAt != null &&
          _isSameDay(completedAt, date);
    }).toList();
  }

  bool get hasAnyRecord {
    return hasDailyStatus ||
        hasRehabAction ||
        hasPostureRecord ||
        hasCompletedMilestone;
  }

  int? get postSurgeryDay => profile?.postSurgeryDay(date);

  PostureSummary get postureSummary {
    return PostureSummary(
      sessions: postureSessions,
      now: date.add(const Duration(days: 1)),
    );
  }

  RehabSummary get rehabSummary {
    return RehabSummary(logs: rehabLogs, actions: actions);
  }

  int get postureExceededCount {
    return postureSummary.sittingOverThresholdCount +
        postureSummary.standingOverThresholdCount;
  }

  List<CalendarStatusDot> get dots {
    final values = <CalendarStatusDot>[];
    if (hasMuchWorse) {
      values.add(CalendarStatusDot.muchWorse);
    }
    if (hasPostureExceeded) {
      values.add(CalendarStatusDot.postureExceeded);
    } else if (hasPostureStable) {
      values.add(CalendarStatusDot.postureStable);
    }
    if (hasRehabAction) {
      values.add(CalendarStatusDot.rehabAction);
    }
    if (hasCompletedMilestone) {
      values.add(CalendarStatusDot.milestoneCompleted);
    }
    if (values.isEmpty) {
      return hasAnyRecord ? const [] : [CalendarStatusDot.none];
    }
    return values.take(3).toList();
  }

  String actionNameFor(int actionId) {
    for (final action in actions) {
      if (action.id == actionId) {
        return action.name;
      }
    }
    return '康复动作';
  }
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
