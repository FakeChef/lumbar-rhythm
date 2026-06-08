import '../data/rehab_repository.dart';
import '../domain/action_item.dart';

enum PostureReminderFollowUp {
  stoodUp,
  satDown,
  snoozeFiveMinutes,
  recordDiscomfort,
  shortWalk,
  relaxationRest,
}

extension PostureReminderFollowUpLabel on PostureReminderFollowUp {
  String get label {
    return switch (this) {
      PostureReminderFollowUp.stoodUp => '我已起身',
      PostureReminderFollowUp.satDown => '我已坐下休息',
      PostureReminderFollowUp.snoozeFiveMinutes => '稍后 5 分钟',
      PostureReminderFollowUp.recordDiscomfort => '记录不适',
      PostureReminderFollowUp.shortWalk => '记录一次短时步行',
      PostureReminderFollowUp.relaxationRest => '记录一次放松 / 休息',
    };
  }
}

class PostureReminderRehabLink {
  const PostureReminderRehabLink(this._repository);

  final RehabRepository _repository;

  Future<RehabLog?> recordShortWalk({DateTime? createdAt}) async {
    final action = await _findFirstAction(
      activityIds: ['short_walking_program'],
      categories: ['WALK'],
      names: ['短距离步行', '平地步行', '步行'],
    );
    if (action == null) {
      return null;
    }
    return _repository.addLog(
      action: action,
      amount: '3',
      unit: '分钟',
      reaction: RehabReaction.noChange,
      source: 'posture_reminder',
      createdAt: createdAt,
    );
  }

  Future<RehabLog?> recordSittingBreak({DateTime? createdAt}) async {
    final action = await _findFirstAction(
      activityIds: ['short_walking_program'],
      categories: ['WALK'],
      names: ['短距离步行', '久坐中断'],
    );
    if (action == null) {
      return null;
    }
    return _repository.addLog(
      action: action,
      amount: '1',
      unit: action.defaultUnit,
      reaction: RehabReaction.noChange,
      source: 'posture_session',
      createdAt: createdAt,
    );
  }

  Future<RehabLog?> recordRelaxationRest({DateTime? createdAt}) async {
    final action = await _findFirstAction(
      activityIds: [
        'diaphragmatic_breathing',
        'log_rolling',
      ],
      categories: ['BASIC'],
      names: [
        '膈式呼吸',
        '圆木滚动转身',
        '站立姿势重置',
        '仰卧放松',
        '一脚垫高放松站姿',
      ],
    );
    if (action == null) {
      return null;
    }
    return _repository.addLog(
      action: action,
      amount: '3',
      unit: action.defaultUnit,
      reaction: RehabReaction.noChange,
      source: 'posture_reminder',
      createdAt: createdAt,
    );
  }

  Future<RehabAction?> _findFirstAction({
    required List<String> activityIds,
    required List<String> categories,
    required List<String> names,
  }) async {
    final actions = await _repository.loadActions();
    for (final activityId in activityIds) {
      for (final action in actions) {
        if (action.activityId == activityId) {
          return action;
        }
      }
    }
    for (final name in names) {
      for (final action in actions) {
        if (action.name == name) {
          return action;
        }
      }
    }
    for (final category in categories) {
      for (final action in actions) {
        if (action.category == category) {
          return action;
        }
      }
    }
    return null;
  }
}
