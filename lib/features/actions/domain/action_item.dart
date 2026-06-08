class RehabActivity {
  const RehabActivity({
    required this.id,
    required this.nameCn,
    required this.category,
    required this.phaseStart,
    required this.phaseEnd,
    required this.defaultUnit,
    required this.optionalUnits,
    required this.riskLevel,
    required this.requiresDoctorClearance,
    required this.isDefaultVisible,
    required this.isCoreActivity,
    required this.sortOrder,
    required this.patientTip,
    required this.stopRule,
  });

  final String id;
  final String nameCn;
  final String category;
  final String phaseStart;
  final String phaseEnd;
  final String defaultUnit;
  final List<String> optionalUnits;
  final String riskLevel;
  final bool requiresDoctorClearance;
  final bool isDefaultVisible;
  final bool isCoreActivity;
  final int sortOrder;
  final String patientTip;
  final String stopRule;

  RehabAction toLegacyAction() {
    return RehabAction(
      id: sortOrder,
      activityId: id,
      name: nameCn,
      category: category,
      defaultUnit: _unitLabel(defaultUnit),
      optionalUnits: optionalUnits.map(_unitLabel).toList(),
      guidance: patientTip,
    );
  }
}

class AuxiliaryRecoveryRecordItem {
  const AuxiliaryRecoveryRecordItem({
    required this.id,
    required this.nameCn,
    required this.valueHint,
  });

  final String id;
  final String nameCn;
  final String valueHint;
}

const auxiliaryRecoveryRecordItems = [
  AuxiliaryRecoveryRecordItem(
    id: 'pain_score',
    nameCn: '疼痛评分',
    valueHint: '0-10 分',
  ),
  AuxiliaryRecoveryRecordItem(
    id: 'numbness_score',
    nameCn: '麻木/刺痛评分',
    valueHint: '0-10 分',
  ),
  AuxiliaryRecoveryRecordItem(
    id: 'fatigue_score',
    nameCn: '疲劳评分',
    valueHint: '0-10 分',
  ),
  AuxiliaryRecoveryRecordItem(
    id: 'next_day_reaction',
    nameCn: '次日反应',
    valueHint: 'none / mild / obvious / severe',
  ),
];

// TODO: Connect auxiliaryRecoveryRecordItems to DailyRecoveryNote when the
// daily note flow is expanded beyond the current lightweight summary.

const activityMasterV1 = [
  RehabActivity(
    id: 'log_rolling',
    nameCn: '圆木滚动转身',
    category: 'BASIC',
    phaseStart: 'P1',
    phaseEnd: 'P1',
    defaultUnit: 'times',
    optionalUnits: ['times', 'reps'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 1,
    patientTip: '像整体翻身一样慢慢转动，记录完成次数。',
    stopRule: '如果转身时不适明显增加，先停下休息。',
  ),
  RehabActivity(
    id: 'ankle_pump',
    nameCn: '踝泵运动',
    category: 'BASIC',
    phaseStart: 'P1',
    phaseEnd: 'P1',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 2,
    patientTip: '轻柔活动脚踝，保持呼吸自然，记录次数。',
    stopRule: '如果腿部不适增加，暂停并观察。',
  ),
  RehabActivity(
    id: 'diaphragmatic_breathing',
    nameCn: '膈式呼吸',
    category: 'BASIC',
    phaseStart: 'P1',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'reps'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 3,
    patientTip: '选择舒适姿势，放慢呼吸并记录时间。',
    stopRule: '如果头晕或不舒服，恢复自然呼吸。',
  ),
  RehabActivity(
    id: 'short_walking_program',
    nameCn: '短距离步行',
    category: 'WALK',
    phaseStart: 'P1',
    phaseEnd: 'P2',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'times'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 4,
    patientTip: '按舒适节奏短距离走动，记录持续时间。',
    stopRule: '如果疲劳或不适升高，缩短时长并休息。',
  ),
  RehabActivity(
    id: 'adim_tra_bracing',
    nameCn: '腹部抽吸动作',
    category: 'CORE',
    phaseStart: 'P1',
    phaseEnd: 'P2',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'reps'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 5,
    patientTip: '轻轻收住腹部，保持自然呼吸，记录保持时间。',
    stopRule: '如果憋气或不适，放松后再记录。',
  ),
  RehabActivity(
    id: 'multifidi_isometrics',
    nameCn: '多裂肌等长收缩',
    category: 'CORE',
    phaseStart: 'P1',
    phaseEnd: 'P2',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'reps'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 6,
    patientTip: '用很小的力量维持稳定感，记录保持时间。',
    stopRule: '如果腰背紧张增加，减少用力或暂停。',
  ),
  RehabActivity(
    id: 'glute_sets',
    nameCn: '臀部等长收缩',
    category: 'HIP_LEG',
    phaseStart: 'P1',
    phaseEnd: 'P2',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 7,
    patientTip: '轻轻收紧臀部后放松，记录完成次数。',
    stopRule: '如果腰背压力增加，降低力度或暂停。',
  ),
  RehabActivity(
    id: 'gentle_neural_gliding',
    nameCn: '仰卧位神经轻柔滑动',
    category: 'MOBILITY',
    phaseStart: 'P1',
    phaseEnd: 'P2',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: false,
    isCoreActivity: false,
    sortOrder: 8,
    patientTip: '只在舒适范围内轻柔滑动，记录次数。',
    stopRule: '如果麻刺感或不适增加，立即停止。',
  ),
  RehabActivity(
    id: 'bird_dog',
    nameCn: '四足位对侧抬起',
    category: 'CORE',
    phaseStart: 'P2',
    phaseEnd: 'P3',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 9,
    patientTip: '保持动作小而稳，记录左右交替次数。',
    stopRule: '如果身体晃动或不适增加，先降低难度。',
  ),
  RehabActivity(
    id: 'supine_bridging',
    nameCn: '仰卧位臀桥',
    category: 'HIP_LEG',
    phaseStart: 'P2',
    phaseEnd: 'P3',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 10,
    patientTip: '小幅度抬起髋部，记录完成次数。',
    stopRule: '如果腰背压力明显增加，降低幅度或暂停。',
  ),
  RehabActivity(
    id: 'side_lying_clamshells',
    nameCn: '侧卧蚌式开合',
    category: 'HIP_LEG',
    phaseStart: 'P2',
    phaseEnd: 'P3',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 11,
    patientTip: '侧卧小幅开合，记录次数。',
    stopRule: '如果髋部或腰背不适增加，暂停。',
  ),
  RehabActivity(
    id: 'wall_squats',
    nameCn: '靠墙半蹲',
    category: 'HIP_LEG',
    phaseStart: 'P2',
    phaseEnd: 'P3',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 12,
    patientTip: '靠墙保持稳定，小幅下蹲并记录次数。',
    stopRule: '如果膝、髋或腰背不适增加，减少幅度。',
  ),
  RehabActivity(
    id: 'stationary_bike',
    nameCn: '固定式自行车',
    category: 'AEROBIC',
    phaseStart: 'P2',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 13,
    patientTip: '使用轻松强度，记录骑行时间。',
    stopRule: '如果不适增加，降低强度或停止。',
  ),
  RehabActivity(
    id: 'single_leg_stance',
    nameCn: '单腿站立平衡',
    category: 'HIP_LEG',
    phaseStart: 'P2',
    phaseEnd: 'P3',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 14,
    patientTip: '扶稳后练习平衡，记录保持时间。',
    stopRule: '如果站立不稳或不适增加，先停下。',
  ),
  RehabActivity(
    id: 'lower_quarter_flexibility',
    nameCn: '下肢灵活性拉伸',
    category: 'MOBILITY',
    phaseStart: 'P2',
    phaseEnd: 'P4',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 15,
    patientTip: '保持轻柔拉伸感，记录保持时间。',
    stopRule: '如果出现刺痛或不适增加，立即放松。',
  ),
  RehabActivity(
    id: 'front_side_plank',
    nameCn: '平板支撑与侧支撑',
    category: 'CORE',
    phaseStart: 'P3',
    phaseEnd: 'P4',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 16,
    patientTip: '采用能稳定完成的支撑方式，记录保持时间。',
    stopRule: '如果腰背或肩部不适增加，先放下休息。',
  ),
  RehabActivity(
    id: 'swiss_ball_core',
    nameCn: '瑞士球核心稳定',
    category: 'CORE',
    phaseStart: 'P3',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'reps'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: false,
    isCoreActivity: false,
    sortOrder: 17,
    patientTip: '只选择容易保持稳定的动作，记录时间。',
    stopRule: '如果平衡变差或不适增加，立即停止。',
  ),
  RehabActivity(
    id: 'resistance_band_dynamic',
    nameCn: '阻力带复合训练',
    category: 'CORE',
    phaseStart: 'P3',
    phaseEnd: 'P4',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 18,
    patientTip: '使用轻阻力并保持平稳，记录次数。',
    stopRule: '如果拉力让不适增加，停止本次记录。',
  ),
  RehabActivity(
    id: 'squats_lunges',
    nameCn: '功能性下蹲与弓步',
    category: 'HIP_LEG',
    phaseStart: 'P3',
    phaseEnd: 'P4',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 19,
    patientTip: '保持动作可控，记录完成次数。',
    stopRule: '如果膝、髋或腰背不适增加，减少幅度。',
  ),
  RehabActivity(
    id: 'aquatics_swimming',
    nameCn: '水中康复与游泳',
    category: 'AEROBIC',
    phaseStart: 'P3',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 20,
    patientTip: '选择轻松水中活动，记录时间。',
    stopRule: '如果疲劳或不适增加，结束本次活动。',
  ),
  RehabActivity(
    id: 'clinical_pilates',
    nameCn: '临床普拉提训练',
    category: 'CORE',
    phaseStart: 'P3',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'reps'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: false,
    isCoreActivity: false,
    sortOrder: 21,
    patientTip: '选择熟悉且可控的动作，记录训练时间。',
    stopRule: '如果动作控制变差或不适增加，暂停。',
  ),
  RehabActivity(
    id: 'outdoor_biking',
    nameCn: '户外骑行与山地自行车',
    category: 'AEROBIC',
    phaseStart: 'P4',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes'],
    riskLevel: 'high',
    requiresDoctorClearance: true,
    isDefaultVisible: false,
    isCoreActivity: false,
    sortOrder: 22,
    patientTip: '仅记录已经被线下确认适合自己的骑行活动。',
    stopRule: '如果疲劳、不稳或不适增加，结束本次活动。',
  ),
  RehabActivity(
    id: 'jogging_running',
    nameCn: '慢跑与跑步恢复',
    category: 'AEROBIC',
    phaseStart: 'P4',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes'],
    riskLevel: 'high',
    requiresDoctorClearance: true,
    isDefaultVisible: false,
    isCoreActivity: false,
    sortOrder: 23,
    patientTip: '仅记录已经被线下确认适合自己的跑步活动。',
    stopRule: '如果冲击感、不稳或不适增加，停止本次活动。',
  ),
  RehabActivity(
    id: 'plyometrics_agility',
    nameCn: '增强式训练与敏捷性响应',
    category: 'SPORT',
    phaseStart: 'P4',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'reps'],
    riskLevel: 'high',
    requiresDoctorClearance: true,
    isDefaultVisible: false,
    isCoreActivity: false,
    sortOrder: 24,
    patientTip: '仅记录已经被线下确认适合自己的敏捷活动。',
    stopRule: '如果落地不稳、疲劳或不适增加，立即停止。',
  ),
  RehabActivity(
    id: 'work_simulation_lifting',
    nameCn: '高负荷职业模拟提举',
    category: 'FUNCTION',
    phaseStart: 'P4',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'reps'],
    riskLevel: 'high',
    requiresDoctorClearance: true,
    isDefaultVisible: false,
    isCoreActivity: false,
    sortOrder: 25,
    patientTip: '仅记录已经被线下确认适合自己的提举模拟。',
    stopRule: '如果动作变形、疲劳或不适增加，停止本次活动。',
  ),
];

const rehabPhases = ['P1', 'P2', 'P3', 'P4'];

String rehabPhaseForPostSurgeryDay(int? postSurgeryDay) {
  final day = postSurgeryDay ?? 1;
  if (day <= 28) {
    return 'P1';
  }
  if (day <= 56) {
    return 'P2';
  }
  if (day <= 84) {
    return 'P3';
  }
  return 'P4';
}

String rehabPhaseTitle(String phase) {
  return switch (phase) {
    'P1' => '阶段一',
    'P2' => '阶段二',
    'P3' => '阶段三',
    'P4' => '阶段四',
    _ => phase,
  };
}

String rehabPhaseDescription(String phase) {
  return switch (phase) {
    'P1' => '急性愈合与神经运动唤醒期',
    'P2' => '运动控制与早期动态稳定期',
    'P3' => '动态稳定进阶与功能性负荷期',
    'P4' => '高负荷恢复与重返运动期',
    _ => '康复活动记录',
  };
}

bool rehabActivityIsInPhase(RehabActivity activity, String phase) {
  final current = _phaseIndex(phase);
  return current >= _phaseIndex(activity.phaseStart) &&
      current <= _phaseIndex(activity.phaseEnd);
}

int _phaseIndex(String phase) {
  return int.tryParse(phase.replaceFirst('P', '')) ?? 1;
}

const legacyActionIdToActivityId = {
  1: 'short_walking_program',
  2: 'short_walking_program',
  3: 'diaphragmatic_breathing',
  4: 'log_rolling',
  5: 'short_walking_program',
  6: 'log_rolling',
  7: 'adim_tra_bracing',
  8: 'bird_dog',
  9: 'front_side_plank',
  10: 'log_rolling',
};

String? legacyActionNameForId(int actionId) {
  final activityId = legacyActionIdToActivityId[actionId];
  if (activityId == null) {
    return null;
  }
  return activityMasterV1
      .firstWhere((activity) => activity.id == activityId)
      .nameCn;
}

class RehabAction {
  const RehabAction({
    required this.id,
    required this.name,
    required this.defaultUnit,
    required this.guidance,
    this.activityId,
    this.category,
    this.optionalUnits = const [],
  });

  final int id;
  final String? activityId;
  final String name;
  final String? category;
  final String defaultUnit;
  final List<String> optionalUnits;
  final String guidance;
}

final actionLibrary = [
  for (final activity in activityMasterV1) activity.toLegacyAction(),
];

RehabActivity? activityForAction(RehabAction action) {
  final activityId = action.activityId;
  for (final activity in activityMasterV1) {
    if (activity.id == activityId || activity.sortOrder == action.id) {
      return activity;
    }
  }
  return null;
}

String _unitLabel(String unit) {
  return _UnitLabels.byKey[unit] ?? unit;
}

abstract final class _UnitLabels {
  static const byKey = {
    'minutes': '分钟',
    'times_per_day': '次/天',
    'times': '次',
    'reps': '次',
    'seconds_hold': '秒',
    'sets': '组',
  };
}

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
    required this.amountValue,
    required this.unit,
    required this.reaction,
    required this.source,
    required this.createdAt,
    this.symptomTag,
    this.symptomTags = const [],
    this.preSymptomScore,
    this.postSymptomScore,
    this.note,
  });

  final int id;
  final int actionId;
  final String amount;
  final double amountValue;
  final String unit;
  final RehabReaction reaction;
  final String source;
  final String? symptomTag;
  final List<String> symptomTags;
  final int? preSymptomScore;
  final int? postSymptomScore;
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
    final matchingNames = _equivalentActionNames(name);
    final matchingActionIds = actions
        .where((action) {
          if (matchingNames.contains(action.name)) {
            return true;
          }
          if (_isWalkingQuery(name)) {
            return action.category == 'WALK';
          }
          return false;
        })
        .map((action) => action.id)
        .toSet();
    return logs
        .where((log) => matchingActionIds.contains(log.actionId))
        .map((log) => log.amountValue)
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

  String observationActionNames() {
    final actionNamesById = {
      for (final action in actions) action.id: action.name,
    };
    final names = logs
        .where((log) => log.reaction == RehabReaction.muchWorse)
        .map((log) =>
            actionNamesById[log.actionId] ??
            legacyActionNameForId(log.actionId))
        .whereType<String>()
        .toSet()
        .toList();

    return names.isEmpty ? '暂无' : names.join('、');
  }
}

bool _isWalkingQuery(String name) {
  return name == '步行' || name == '平地步行';
}

Set<String> _equivalentActionNames(String name) {
  return switch (name) {
    '步行' || '平地步行' => {'步行', '平地步行', '短距离步行'},
    '仰卧放松' || '站立姿势重置' => {'仰卧放松', '站立姿势重置'},
    '侧桥简化版' || '改良侧桥' => {'侧桥简化版', '改良侧桥'},
    _ => {name},
  };
}
