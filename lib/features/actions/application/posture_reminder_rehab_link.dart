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

  Future<RehabLog> recordShortWalk({DateTime? createdAt}) async {
    final action = await _findActionByName('步行');
    return _repository.addLog(
      action: action,
      amount: '3',
      unit: '分钟',
      reaction: RehabReaction.noChange,
      source: 'posture_reminder',
      createdAt: createdAt,
    );
  }

  Future<RehabLog> recordRelaxationRest({DateTime? createdAt}) async {
    final action = await _findFirstActionByNames([
      '仰卧放松',
      '一脚垫高放松站姿',
    ]);
    return _repository.addLog(
      action: action,
      amount: '3',
      unit: action.defaultUnit,
      reaction: RehabReaction.noChange,
      source: 'posture_reminder',
      createdAt: createdAt,
    );
  }

  Future<RehabAction> _findActionByName(String name) async {
    return _findFirstActionByNames([name]);
  }

  Future<RehabAction> _findFirstActionByNames(List<String> names) async {
    final actions = await _repository.loadActions();
    for (final name in names) {
      for (final action in actions) {
        if (action.name == name) {
          return action;
        }
      }
    }
    throw StateError('Required rehab action template is missing.');
  }
}
