class ActionItem {
  const ActionItem({
    required this.name,
    required this.duration,
    required this.instructions,
  });

  final String name;
  final String duration;
  final String instructions;
}

const actionLibrary = [
  ActionItem(
    name: '站起走动',
    duration: '2-3 分钟',
    instructions: '离开座位，缓慢走动，让身体从固定姿势中放松出来。',
  ),
  ActionItem(
    name: '肩背放松',
    duration: '1 分钟',
    instructions: '自然站立或坐直，轻轻打开肩背，避免用力后仰或快速扭转。',
  ),
  ActionItem(
    name: '髋部轻活动',
    duration: '1-2 分钟',
    instructions: '扶稳桌面或墙面，缓慢活动髋部和下肢，保持动作温和。',
  ),
  ActionItem(
    name: '呼吸休息',
    duration: '1 分钟',
    instructions: '保持舒适姿势，放慢呼吸，观察身体感受，不强行拉伸。',
  ),
  ActionItem(
    name: '短暂坐下',
    duration: '2 分钟',
    instructions: '久站后短暂坐下休息，调整姿势，避免长时间保持同一状态。',
  ),
];
