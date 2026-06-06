import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/data/rehab_repository.dart';
import '../../actions/domain/action_item.dart';
import '../../posture/application/posture_session_controller.dart';
import '../../posture/domain/posture_session.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../recovery/domain/recovery_profile.dart';
import '../../reports/application/daily_report_controller.dart';
import '../../settings/application/reminder_settings_controller.dart';
import '../../settings/domain/reminder_settings.dart';

final _homeRehabActionsProvider = FutureProvider<List<RehabAction>>((ref) {
  return ref.watch(rehabRepositoryProvider).loadActions();
});

final _homeRecoveryProfileProvider = FutureProvider((ref) {
  return ref.watch(recoveryRepositoryProvider).loadProfile();
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  PostureType _selectedPosture = PostureType.sitting;
  RehabAction? _selectedAction;
  String _rehabAmount = '1';
  String _rehabUnit = '分钟';
  RehabReaction _rehabReaction = RehabReaction.noChange;
  String? _rehabSymptomTag;
  String? _rehabNote;

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(reminderSettingsControllerProvider);
    final postureState = ref.watch(postureSessionControllerProvider);
    final rehabActionsState = ref.watch(_homeRehabActionsProvider);
    final recoveryProfileState = ref.watch(_homeRecoveryProfileProvider);
    final postureNow =
        ref.watch(postureClockProvider).valueOrNull ?? DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        _refresh(ref);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '腰椎节奏',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '术后康复日志、坐站提醒与本地报告',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '刷新首页',
                icon: const Icon(Icons.refresh_outlined),
                onPressed: () => _refresh(ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          recoveryProfileState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取康复资料'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '康复资料读取失败',
              onRetry: () => ref.invalidate(_homeRecoveryProfileProvider),
            ),
            data: (profile) => _RecoveryStatusCard(profile: profile),
          ),
          const SizedBox(height: 12),
          settingsState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取提醒设置'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '提醒设置读取失败',
              onRetry: () => ref.invalidate(reminderSettingsControllerProvider),
            ),
            data: (settings) => postureState.when(
              loading: () => const _HomeLoadingCard(title: '正在读取当前姿势'),
              error: (error, stackTrace) => _HomeErrorCard(
                title: '当前姿势读取失败',
                onRetry: () => ref.invalidate(postureSessionControllerProvider),
              ),
              data: (session) => _PostureStatusCard(
                session: session,
                now: postureNow,
                settings: settings,
                selectedPosture: _selectedPosture,
                onSelectedPostureChanged: (type) {
                  if (type != null) {
                    setState(() => _selectedPosture = type);
                  }
                },
                onStartOrSwitch: () async {
                  await ref
                      .read(postureSessionControllerProvider.notifier)
                      .switchTo(_selectedPosture);
                },
                onEndCurrent: () async {
                  await ref
                      .read(postureSessionControllerProvider.notifier)
                      .endCurrent();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          rehabActionsState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取康复动作'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '康复动作读取失败',
              onRetry: () => ref.invalidate(_homeRehabActionsProvider),
            ),
            data: (actions) {
              final selectedAction = _selectedAction != null &&
                      actions.any((action) => action.id == _selectedAction!.id)
                  ? _selectedAction
                  : (actions.isEmpty ? null : actions.first);
              return _RehabEntryCard(
                actions: actions,
                selectedAction: selectedAction,
                amount: _rehabAmount,
                unit: _rehabUnit,
                reaction: _rehabReaction,
                symptomTag: _rehabSymptomTag,
                note: _rehabNote,
                onActionChanged: (action) {
                  if (action == null) return;
                  setState(() {
                    _selectedAction = action;
                    _rehabUnit = action.defaultUnit;
                  });
                },
                onAmountChanged: (value) => _rehabAmount = value,
                onUnitChanged: (value) {
                  if (value != null) setState(() => _rehabUnit = value);
                },
                onReactionChanged: (value) {
                  if (value != null) setState(() => _rehabReaction = value);
                },
                onSymptomTagChanged: (value) {
                  setState(() => _rehabSymptomTag = value);
                },
                onNoteChanged: (value) => _rehabNote = value,
                onSave: () => _saveRehabLog(actions),
              );
            },
          ),
          const SizedBox(height: 12),
          _DailyRecoveryNoteCard(
            onTap: () => _showDailyRecoveryNoteDialog(context),
          ),
        ],
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(postureSessionControllerProvider);
    ref.invalidate(reminderSettingsControllerProvider);
    ref.invalidate(_homeRehabActionsProvider);
    ref.invalidate(_homeRecoveryProfileProvider);
  }

  Future<void> _saveRehabLog(List<RehabAction> actions) async {
    final action = _selectedAction ?? (actions.isEmpty ? null : actions.first);
    if (action == null) {
      return;
    }

    await ref.read(rehabRepositoryProvider).addLog(
          action: action,
          amount: _rehabAmount,
          unit: _rehabUnit,
          reaction: _rehabReaction,
          symptomTag: _rehabSymptomTag,
          note: _rehabNote,
        );
    ref.invalidate(dailyReportControllerProvider);

    if (!mounted) {
      return;
    }

    final message = _rehabReaction == RehabReaction.muchWorse
        ? '建议减少量或暂停观察，必要时咨询医生或康复师。'
        : '已保存康复记录';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showDailyRecoveryNoteDialog(BuildContext context) async {
    final repository = ref.read(recoveryRepositoryProvider);
    final today = DateTime.now();
    final existing = await repository.loadNote(today);
    if (!context.mounted) return;

    var feeling = existing?.overallFeeling ?? OverallFeeling.same;
    var backPain = existing?.backPainScore ?? 0;
    var legSymptom = existing?.legSymptomScore ?? 0;
    var fatigue = existing?.fatigueScore ?? 0;
    var note = existing?.note ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('今日康复小结'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<OverallFeeling>(
                      initialValue: feeling,
                      decoration: const InputDecoration(labelText: '总体感觉'),
                      items: [
                        for (final value in OverallFeeling.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => feeling = value);
                        }
                      },
                    ),
                    _ScoreSlider(
                      label: '腰部不适',
                      value: backPain,
                      onChanged: (value) =>
                          setDialogState(() => backPain = value),
                    ),
                    _ScoreSlider(
                      label: '腿部症状',
                      value: legSymptom,
                      onChanged: (value) =>
                          setDialogState(() => legSymptom = value),
                    ),
                    _ScoreSlider(
                      label: '疲劳感',
                      value: fatigue,
                      onChanged: (value) =>
                          setDialogState(() => fatigue = value),
                    ),
                    TextFormField(
                      initialValue: note,
                      decoration: const InputDecoration(labelText: '备注（可选）'),
                      maxLines: 3,
                      onChanged: (value) => note = value,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(this.context);
    await repository.saveNote(
      date: today,
      overallFeeling: feeling,
      backPainScore: backPain,
      legSymptomScore: legSymptom,
      fatigueScore: fatigue,
      note: note,
    );
    ref.invalidate(dailyReportControllerProvider);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('已保存今日康复小结')),
    );
  }
}

class _RecoveryStatusCard extends StatelessWidget {
  const _RecoveryStatusCard({required this.profile});

  final RecoveryProfile? profile;

  @override
  Widget build(BuildContext context) {
    final day = profile?.postSurgeryDay(DateTime.now());
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timeline_outlined),
        title: Text(day == null ? '康复资料' : '术后第 $day 天'),
        subtitle: Text(day == null ? '可在设置中添加手术日期。' : '持续记录自己的康复之路。'),
      ),
    );
  }
}

class _DailyRecoveryNoteCard extends StatelessWidget {
  const _DailyRecoveryNoteCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.edit_note_outlined),
        title: const Text('今日康复小结'),
        subtitle: const Text('记录总体感觉、腰部不适、腿部症状和疲劳感。'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('$label：$value/10'),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: '$value',
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
    );
  }
}

class _PostureStatusCard extends StatelessWidget {
  const _PostureStatusCard({
    required this.session,
    required this.now,
    required this.settings,
    required this.selectedPosture,
    required this.onSelectedPostureChanged,
    required this.onStartOrSwitch,
    required this.onEndCurrent,
  });

  final PostureSession? session;
  final DateTime now;
  final ReminderSettings settings;
  final PostureType selectedPosture;
  final ValueChanged<PostureType?> onSelectedPostureChanged;
  final VoidCallback onStartOrSwitch;
  final VoidCallback onEndCurrent;

  @override
  Widget build(BuildContext context) {
    final current = session;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardHeader(
              icon: Icons.timer_outlined,
              title: '当前姿势',
              trailing: current == null
                  ? '00:00'
                  : _formatDuration(current.durationAt(now)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PostureType>(
              initialValue: selectedPosture,
              decoration: const InputDecoration(labelText: '选择当前姿势'),
              items: [
                for (final type in PostureType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(_postureMenuLabel(type)),
                  ),
              ],
              onChanged: onSelectedPostureChanged,
            ),
            const SizedBox(height: 12),
            Text(
              current == null
                  ? '当前状态：未开始'
                  : '当前状态：${_postureMenuLabel(current.type)}',
            ),
            const SizedBox(height: 4),
            Text('当前提醒阈值：${_thresholdText(current?.type ?? selectedPosture)}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onStartOrSwitch,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('开始/切换'),
            ),
            if (current != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onEndCurrent,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('结束当前状态'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _thresholdText(PostureType type) {
    return switch (type) {
      PostureType.sitting => '久坐 ${settings.sittingIntervalMinutes} 分钟',
      PostureType.standing => '久站 ${settings.standingIntervalMinutes} 分钟',
      PostureType.walking || PostureType.resting => '不安排坐站提醒',
    };
  }

  String _postureMenuLabel(PostureType type) {
    return switch (type) {
      PostureType.sitting => '坐着',
      PostureType.standing => '站着',
      PostureType.walking => '走动',
      PostureType.resting => '休息',
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _RehabEntryCard extends StatelessWidget {
  const _RehabEntryCard({
    required this.actions,
    required this.selectedAction,
    required this.amount,
    required this.unit,
    required this.reaction,
    required this.symptomTag,
    required this.note,
    required this.onActionChanged,
    required this.onAmountChanged,
    required this.onUnitChanged,
    required this.onReactionChanged,
    required this.onSymptomTagChanged,
    required this.onNoteChanged,
    required this.onSave,
  });

  static const _units = ['分钟', '次', '组', '秒'];
  static const _symptomTags = ['腰酸', '腰痛', '臀腿痛', '腿麻', '脚背刺痛', '疲劳'];

  final List<RehabAction> actions;
  final RehabAction? selectedAction;
  final String amount;
  final String unit;
  final RehabReaction reaction;
  final String? symptomTag;
  final String? note;
  final ValueChanged<RehabAction?> onActionChanged;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String?> onUnitChanged;
  final ValueChanged<RehabReaction?> onReactionChanged;
  final ValueChanged<String?> onSymptomTagChanged;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeader(
              icon: Icons.accessibility_new_outlined,
              title: '今日康复动作',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RehabAction>(
              initialValue: selectedAction,
              decoration: const InputDecoration(labelText: '选择康复动作'),
              items: [
                for (final action in actions)
                  DropdownMenuItem(value: action, child: Text(action.name)),
              ],
              onChanged: onActionChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: amount,
                    decoration: const InputDecoration(labelText: '完成量'),
                    keyboardType: TextInputType.number,
                    onChanged: onAmountChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: const InputDecoration(labelText: '单位'),
                    items: [
                      for (final value in _units)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: onUnitChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RehabReaction>(
              initialValue: reaction,
              decoration: const InputDecoration(labelText: '做后感觉'),
              items: [
                for (final value in RehabReaction.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: onReactionChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: symptomTag,
              decoration: const InputDecoration(labelText: '症状标签（可选）'),
              items: [
                const DropdownMenuItem(value: null, child: Text('不选择')),
                for (final value in _symptomTags)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: onSymptomTagChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: note,
              decoration: const InputDecoration(labelText: '备注（可选）'),
              maxLines: 2,
              onChanged: onNoteChanged,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: selectedAction == null ? null : onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存记录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
      ],
    );
  }
}

class _HomeLoadingCard extends StatelessWidget {
  const _HomeLoadingCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(title),
      ),
    );
  }
}

class _HomeErrorCard extends StatelessWidget {
  const _HomeErrorCard({
    required this.title,
    required this.onRetry,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(title),
        trailing: TextButton(
          onPressed: onRetry,
          child: const Text('重试'),
        ),
      ),
    );
  }
}
