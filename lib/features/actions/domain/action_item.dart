class RehabAction {
  const RehabAction({
    required this.id,
    required this.name,
    required this.defaultUnit,
    required this.guidance,
  });

  final int id;
  final String name;
  final String defaultUnit;
  final String guidance;
}

const actionLibrary = [
  RehabAction(
    id: 1,
    name: '步行',
    defaultUnit: '分钟',
    guidance: '按自己舒适节奏记录一次步行。',
  ),
  RehabAction(
    id: 2,
    name: '室内慢走',
    defaultUnit: '分钟',
    guidance: '在室内缓慢走动，留意身体反应。',
  ),
  RehabAction(
    id: 3,
    name: '腹式呼吸',
    defaultUnit: '次',
    guidance: '选择舒适姿势，放慢呼吸并记录完成量。',
  ),
  RehabAction(
    id: 4,
    name: '肩胛后收',
    defaultUnit: '次',
    guidance: '轻轻向后收肩胛，避免憋气和猛发力。',
  ),
  RehabAction(
    id: 5,
    name: '坐站转换',
    defaultUnit: '次',
    guidance: '从坐到站缓慢转换，记录完成次数。',
  ),
  RehabAction(
    id: 6,
    name: '仰卧放松',
    defaultUnit: '分钟',
    guidance: '仰卧或舒适躺姿休息，记录持续时间。',
  ),
  RehabAction(
    id: 7,
    name: '腹横肌轻收紧',
    defaultUnit: '次',
    guidance: '轻柔收紧核心，保持自然呼吸。',
  ),
  RehabAction(
    id: 8,
    name: 'Bird-dog 简化版',
    defaultUnit: '次',
    guidance: '降低幅度，按可接受的范围记录。',
  ),
  RehabAction(
    id: 9,
    name: '侧桥简化版',
    defaultUnit: '次',
    guidance: '采用简化支撑方式，记录完成次数。',
  ),
  RehabAction(
    id: 10,
    name: '一脚垫高放松站姿',
    defaultUnit: '分钟',
    guidance: '一脚轻放垫高物，观察站姿放松感。',
  ),
];

enum RehabReaction {
  moreComfortable,
  noChange,
  slightlyWorse,
  muchWorse,
}

extension RehabReactionLabel on RehabReaction {
  String get storageValue => name;

  String get label {
    return switch (this) {
      RehabReaction.moreComfortable => '更舒服',
      RehabReaction.noChange => '没变化',
      RehabReaction.slightlyWorse => '有点加重',
      RehabReaction.muchWorse => '明显加重',
    };
  }
}

class RehabLog {
  const RehabLog({
    required this.id,
    required this.actionId,
    required this.amount,
    required this.unit,
    required this.reaction,
    required this.createdAt,
    this.symptomTag,
    this.note,
  });

  final int id;
  final int actionId;
  final String amount;
  final String unit;
  final RehabReaction reaction;
  final String? symptomTag;
  final String? note;
  final DateTime createdAt;
}

class RehabSummary {
  const RehabSummary({
    required this.logs,
    this.actions = const [],
  });

  final List<RehabLog> logs;
  final List<RehabAction> actions;

  int get totalCount => logs.length;

  int reactionCount(RehabReaction reaction) {
    return logs.where((log) => log.reaction == reaction).length;
  }

  double totalAmountForActionNamed(String name) {
    final matchingActionIds = actions
        .where((action) => action.name == name)
        .map((action) => action.id)
        .toSet();
    return logs
        .where((log) => matchingActionIds.contains(log.actionId))
        .map((log) => double.tryParse(log.amount) ?? 0)
        .fold(0.0, (sum, amount) => sum + amount);
  }

  RehabAction? mostCompletedAction() {
    if (logs.isEmpty || actions.isEmpty) {
      return null;
    }

    final counts = <int, int>{};
    for (final log in logs) {
      counts[log.actionId] = (counts[log.actionId] ?? 0) + 1;
    }
    final topActionId = counts.entries.reduce((left, right) {
      return left.value >= right.value ? left : right;
    }).key;

    for (final action in actions) {
      if (action.id == topActionId) {
        return action;
      }
    }
    return null;
  }
}
