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
    id: 'walk_flat',
    nameCn: '平地步行',
    category: 'WALK',
    phaseStart: 'P0',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'times_per_day'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 1,
    patientTip: '按舒适节奏在平地慢走，记录持续时间。',
    stopRule: '如果不适明显增加，先停下休息并观察。',
  ),
  RehabActivity(
    id: 'walk_segmented',
    nameCn: '分段步行',
    category: 'WALK',
    phaseStart: 'P0',
    phaseEnd: 'P2',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'times_per_day'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 2,
    patientTip: '把步行拆成几小段，按身体反馈记录。',
    stopRule: '如果出现明显不适，减少本次时长并休息。',
  ),
  RehabActivity(
    id: 'walk_endurance',
    nameCn: '连续步行耐力',
    category: 'WALK',
    phaseStart: 'P1',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 3,
    patientTip: '记录一段连续步行时间，保持轻松节奏。',
    stopRule: '如果疲劳或不适升高，缩短时长。',
  ),
  RehabActivity(
    id: 'sit_break',
    nameCn: '久坐中断',
    category: 'BREAK',
    phaseStart: 'P0',
    phaseEnd: 'P4',
    defaultUnit: 'times_per_day',
    optionalUnits: ['times_per_day', 'minutes'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 4,
    patientTip: '坐了一段时间后起身换姿势，记录完成次数。',
    stopRule: '如果起身过程不舒服，放慢动作。',
  ),
  RehabActivity(
    id: 'stand_break',
    nameCn: '久站中断',
    category: 'BREAK',
    phaseStart: 'P0',
    phaseEnd: 'P4',
    defaultUnit: 'times_per_day',
    optionalUnits: ['times_per_day', 'minutes'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 5,
    patientTip: '站久后坐下或走动片刻，记录中断次数。',
    stopRule: '如果站立不适增加，先坐下休息。',
  ),
  RehabActivity(
    id: 'posture_reset',
    nameCn: '站立姿势重置',
    category: 'BREAK',
    phaseStart: 'P0',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'times_per_day'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 6,
    patientTip: '站立时轻轻调整重心和姿势，记录时间。',
    stopRule: '如果调整后仍不舒服，改为休息。',
  ),
  RehabActivity(
    id: 'ankle_pump',
    nameCn: '踝泵',
    category: 'BASIC',
    phaseStart: 'P0',
    phaseEnd: 'P1',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 7,
    patientTip: '轻柔活动脚踝，记录完成次数。',
    stopRule: '如果腿部不适增加，暂停并观察。',
  ),
  RehabActivity(
    id: 'heel_slide',
    nameCn: '足跟滑动',
    category: 'BASIC',
    phaseStart: 'P0',
    phaseEnd: 'P1',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 8,
    patientTip: '在舒适范围内滑动足跟，记录次数。',
    stopRule: '如果动作带来明显不适，先停下。',
  ),
  RehabActivity(
    id: 'abdominal_breathing',
    nameCn: '腹式呼吸',
    category: 'BASIC',
    phaseStart: 'P0',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'reps'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 9,
    patientTip: '选择舒适姿势，放慢呼吸并记录时间。',
    stopRule: '如果头晕或不舒服，恢复自然呼吸。',
  ),
  RehabActivity(
    id: 'abdominal_bracing',
    nameCn: '腹部轻收缩',
    category: 'CORE',
    phaseStart: 'P0',
    phaseEnd: 'P3',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'reps'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 10,
    patientTip: '轻轻收紧腹部，保持自然呼吸。',
    stopRule: '如果憋气或不适，放松后再记录。',
  ),
  RehabActivity(
    id: 'pelvic_neutral',
    nameCn: '骨盆中立训练',
    category: 'CORE',
    phaseStart: 'P0',
    phaseEnd: 'P2',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes', 'reps'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 11,
    patientTip: '在舒适姿势中寻找平稳位置，记录时间。',
    stopRule: '如果腰背紧张增加，减少范围。',
  ),
  RehabActivity(
    id: 'supine_marching',
    nameCn: '仰卧交替抬腿',
    category: 'CORE',
    phaseStart: 'P1',
    phaseEnd: 'P3',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 12,
    patientTip: '保持动作小而稳，记录左右交替次数。',
    stopRule: '如果腰背不适增加，先停止。',
  ),
  RehabActivity(
    id: 'bridge',
    nameCn: '臀桥',
    category: 'HIP_LEG',
    phaseStart: 'P1',
    phaseEnd: 'P4',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 13,
    patientTip: '小幅度抬起髋部，记录完成次数。',
    stopRule: '如果腰背压力明显增加，降低幅度或暂停。',
  ),
  RehabActivity(
    id: 'clamshell',
    nameCn: '蚌式开合',
    category: 'HIP_LEG',
    phaseStart: 'P1',
    phaseEnd: 'P3',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 14,
    patientTip: '侧卧小幅开合，记录次数。',
    stopRule: '如果髋部或腰背不适增加，暂停。',
  ),
  RehabActivity(
    id: 'standing_hip_abduction',
    nameCn: '站姿髋外展',
    category: 'HIP_LEG',
    phaseStart: 'P1',
    phaseEnd: 'P4',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 15,
    patientTip: '扶稳后小幅侧抬腿，记录次数。',
    stopRule: '如果站立不稳或不适增加，先停下。',
  ),
  RehabActivity(
    id: 'heel_raise',
    nameCn: '站姿提踵',
    category: 'HIP_LEG',
    phaseStart: 'P1',
    phaseEnd: 'P4',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'low',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 16,
    patientTip: '扶稳后轻轻提踵，记录次数。',
    stopRule: '如果小腿或腰背不适增加，暂停。',
  ),
  RehabActivity(
    id: 'mini_squat',
    nameCn: '扶桌半蹲',
    category: 'HIP_LEG',
    phaseStart: 'P1',
    phaseEnd: 'P3',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 17,
    patientTip: '扶稳后小幅下蹲，记录次数。',
    stopRule: '如果膝、髋或腰背不适增加，减少幅度。',
  ),
  RehabActivity(
    id: 'bird_dog_basic',
    nameCn: 'Bird-dog 简化版',
    category: 'CORE',
    phaseStart: 'P2',
    phaseEnd: 'P4',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 18,
    patientTip: '降低幅度，保持平稳，记录次数。',
    stopRule: '如果身体晃动或不适增加，先降低难度。',
  ),
  RehabActivity(
    id: 'side_plank_modified',
    nameCn: '改良侧桥',
    category: 'CORE',
    phaseStart: 'P2',
    phaseEnd: 'P4',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 19,
    patientTip: '采用简化支撑，记录保持时间。',
    stopRule: '如果腰背或肩部不适增加，先放下休息。',
  ),
  RehabActivity(
    id: 'pallof_press',
    nameCn: '弹力带抗旋转',
    category: 'CORE',
    phaseStart: 'P2',
    phaseEnd: 'P4',
    defaultUnit: 'reps',
    optionalUnits: ['reps', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: true,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 20,
    patientTip: '使用轻阻力并保持平稳，记录次数。',
    stopRule: '如果拉力让不适增加，停止本次记录。',
  ),
  RehabActivity(
    id: 'hamstring_stretch',
    nameCn: '腘绳肌轻拉伸',
    category: 'MOBILITY',
    phaseStart: 'P1',
    phaseEnd: 'P4',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 21,
    patientTip: '保持轻柔拉伸感，记录保持时间。',
    stopRule: '如果出现刺痛或不适增加，立即放松。',
  ),
  RehabActivity(
    id: 'hip_flexor_stretch',
    nameCn: '髋屈肌拉伸',
    category: 'MOBILITY',
    phaseStart: 'P2',
    phaseEnd: 'P4',
    defaultUnit: 'seconds_hold',
    optionalUnits: ['seconds_hold', 'sets'],
    riskLevel: 'medium',
    requiresDoctorClearance: false,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 22,
    patientTip: '轻柔拉伸髋前侧，记录保持时间。',
    stopRule: '如果腰背压力增加，缩短时间或暂停。',
  ),
  RehabActivity(
    id: 'stationary_bike',
    nameCn: '固定自行车',
    category: 'AEROBIC',
    phaseStart: 'P1',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes'],
    riskLevel: 'medium',
    requiresDoctorClearance: true,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 23,
    patientTip: '使用轻松强度，记录骑行时间。',
    stopRule: '如果不适增加，降低强度或停止。',
  ),
  RehabActivity(
    id: 'swimming_easy',
    nameCn: '轻松游泳/水中步行',
    category: 'AEROBIC',
    phaseStart: 'P2',
    phaseEnd: 'P4',
    defaultUnit: 'minutes',
    optionalUnits: ['minutes'],
    riskLevel: 'medium',
    requiresDoctorClearance: true,
    isDefaultVisible: true,
    isCoreActivity: true,
    sortOrder: 24,
    patientTip: '选择轻松水中活动，记录时间。',
    stopRule: '如果疲劳或不适增加，结束本次活动。',
  ),
];

const legacyActionIdToActivityId = {
  1: 'walk_flat',
  2: 'walk_segmented',
  3: 'abdominal_breathing',
  4: 'posture_reset',
  5: 'sit_break',
  6: 'posture_reset',
  7: 'abdominal_bracing',
  8: 'bird_dog_basic',
  9: 'side_plank_modified',
  10: 'posture_reset',
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

const actionLibrary = [
  RehabAction(id: 1, activityId: 'walk_flat', name: '平地步行', category: 'WALK', defaultUnit: '分钟', optionalUnits: ['分钟', '次/天'], guidance: '按舒适节奏在平地慢走，记录持续时间。'),
  RehabAction(id: 2, activityId: 'walk_segmented', name: '分段步行', category: 'WALK', defaultUnit: '分钟', optionalUnits: ['分钟', '次/天'], guidance: '把步行拆成几小段，按身体反馈记录。'),
  RehabAction(id: 3, activityId: 'walk_endurance', name: '连续步行耐力', category: 'WALK', defaultUnit: '分钟', optionalUnits: ['分钟'], guidance: '记录一段连续步行时间，保持轻松节奏。'),
  RehabAction(id: 4, activityId: 'sit_break', name: '久坐中断', category: 'BREAK', defaultUnit: '次/天', optionalUnits: ['次/天', '分钟'], guidance: '坐了一段时间后起身换姿势，记录完成次数。'),
  RehabAction(id: 5, activityId: 'stand_break', name: '久站中断', category: 'BREAK', defaultUnit: '次/天', optionalUnits: ['次/天', '分钟'], guidance: '站久后坐下或走动片刻，记录中断次数。'),
  RehabAction(id: 6, activityId: 'posture_reset', name: '站立姿势重置', category: 'BREAK', defaultUnit: '分钟', optionalUnits: ['分钟', '次/天'], guidance: '站立时轻轻调整重心和姿势，记录时间。'),
  RehabAction(id: 7, activityId: 'ankle_pump', name: '踝泵', category: 'BASIC', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '轻柔活动脚踝，记录完成次数。'),
  RehabAction(id: 8, activityId: 'heel_slide', name: '足跟滑动', category: 'BASIC', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '在舒适范围内滑动足跟，记录次数。'),
  RehabAction(id: 9, activityId: 'abdominal_breathing', name: '腹式呼吸', category: 'BASIC', defaultUnit: '分钟', optionalUnits: ['分钟', '次'], guidance: '选择舒适姿势，放慢呼吸并记录时间。'),
  RehabAction(id: 10, activityId: 'abdominal_bracing', name: '腹部轻收缩', category: 'CORE', defaultUnit: '秒', optionalUnits: ['秒', '次'], guidance: '轻轻收紧腹部，保持自然呼吸。'),
  RehabAction(id: 11, activityId: 'pelvic_neutral', name: '骨盆中立训练', category: 'CORE', defaultUnit: '分钟', optionalUnits: ['分钟', '次'], guidance: '在舒适姿势中寻找平稳位置，记录时间。'),
  RehabAction(id: 12, activityId: 'supine_marching', name: '仰卧交替抬腿', category: 'CORE', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '保持动作小而稳，记录左右交替次数。'),
  RehabAction(id: 13, activityId: 'bridge', name: '臀桥', category: 'HIP_LEG', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '小幅度抬起髋部，记录完成次数。'),
  RehabAction(id: 14, activityId: 'clamshell', name: '蚌式开合', category: 'HIP_LEG', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '侧卧小幅开合，记录次数。'),
  RehabAction(id: 15, activityId: 'standing_hip_abduction', name: '站姿髋外展', category: 'HIP_LEG', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '扶稳后小幅侧抬腿，记录次数。'),
  RehabAction(id: 16, activityId: 'heel_raise', name: '站姿提踵', category: 'HIP_LEG', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '扶稳后轻轻提踵，记录次数。'),
  RehabAction(id: 17, activityId: 'mini_squat', name: '扶桌半蹲', category: 'HIP_LEG', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '扶稳后小幅下蹲，记录次数。'),
  RehabAction(id: 18, activityId: 'bird_dog_basic', name: 'Bird-dog 简化版', category: 'CORE', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '降低幅度，保持平稳，记录次数。'),
  RehabAction(id: 19, activityId: 'side_plank_modified', name: '改良侧桥', category: 'CORE', defaultUnit: '秒', optionalUnits: ['秒', '组'], guidance: '采用简化支撑，记录保持时间。'),
  RehabAction(id: 20, activityId: 'pallof_press', name: '弹力带抗旋转', category: 'CORE', defaultUnit: '次', optionalUnits: ['次', '组'], guidance: '使用轻阻力并保持平稳，记录次数。'),
  RehabAction(id: 21, activityId: 'hamstring_stretch', name: '腘绳肌轻拉伸', category: 'MOBILITY', defaultUnit: '秒', optionalUnits: ['秒', '组'], guidance: '保持轻柔拉伸感，记录保持时间。'),
  RehabAction(id: 22, activityId: 'hip_flexor_stretch', name: '髋屈肌拉伸', category: 'MOBILITY', defaultUnit: '秒', optionalUnits: ['秒', '组'], guidance: '轻柔拉伸髋前侧，记录保持时间。'),
  RehabAction(id: 23, activityId: 'stationary_bike', name: '固定自行车', category: 'AEROBIC', defaultUnit: '分钟', optionalUnits: ['分钟'], guidance: '使用轻松强度，记录骑行时间。'),
  RehabAction(id: 24, activityId: 'swimming_easy', name: '轻松游泳/水中步行', category: 'AEROBIC', defaultUnit: '分钟', optionalUnits: ['分钟'], guidance: '选择轻松水中活动，记录时间。'),
];

String _unitLabel(String unit) {
  return _UnitLabels.byKey[unit] ?? unit;
}

abstract final class _UnitLabels {
  static const byKey = {
    'minutes': '分钟',
    'times_per_day': '次/天',
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
        .where((action) => matchingNames.contains(action.name))
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
        .map((log) => actionNamesById[log.actionId] ?? legacyActionNameForId(log.actionId))
        .whereType<String>()
        .toSet()
        .toList();

    return names.isEmpty ? '暂无' : names.join('、');
  }
}

Set<String> _equivalentActionNames(String name) {
  return switch (name) {
    '步行' || '平地步行' => {'步行', '平地步行'},
    '仰卧放松' || '站立姿势重置' => {'仰卧放松', '站立姿势重置'},
    '侧桥简化版' || '改良侧桥' => {'侧桥简化版', '改良侧桥'},
    _ => {name},
  };
}
