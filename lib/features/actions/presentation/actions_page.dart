import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../../core/widgets/header_action_button.dart';
import '../../reports/application/daily_report_controller.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../recovery/domain/recovery_profile.dart';
import '../data/rehab_repository.dart';
import '../domain/action_item.dart';

class ActionsPage extends ConsumerStatefulWidget {
  const ActionsPage({super.key});

  @override
  ConsumerState<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends ConsumerState<ActionsPage> {
  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(_rehabPageDataProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        pageState.when(
          loading: () => const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('正在读取康复模板'),
            ),
          ),
          error: (error, stackTrace) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('康复模板读取失败'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(_rehabPageDataProvider),
                child: const Text('重试'),
              ),
            ),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RehabHeaderCard(
                onAdd: () => _showAddLogPicker(context, ref, data),
              ),
              const SizedBox(height: 20),
              _DailyRecoveryNoteCard(
                noteState: data.dailyNoteState,
                onEdit: () => _showDailyRecoveryNoteDialog(
                  context,
                  ref,
                  data.dailyNoteState.note,
                ),
              ),
              const SizedBox(height: 20),
              _TodayRehabLogListCard(data: data),
              const SizedBox(height: 20),
              const _RehabPhaseGuideCard(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDailyRecoveryNoteDialog(
    BuildContext context,
    WidgetRef ref,
    DailyRecoveryNote? note,
  ) async {
    final result = await showModalBottomSheet<_DailyRecoveryNoteDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DailyRecoveryNoteSheet(note: note),
    );
    if (result == null) {
      return;
    }

    await ref.read(recoveryRepositoryProvider).saveNote(
          date: DateTime.now(),
          overallFeeling: result.overallFeeling,
          backPainScore: result.backPainScore,
          legSymptomScore: result.legSymptomScore,
          fatigueScore: result.fatigueScore,
          tags: result.tags,
          note: result.note,
        );
    ref.invalidate(_rehabPageDataProvider);
    ref.invalidate(dailyReportControllerProvider);
    ref.read(appDataRefreshProvider.notifier).state++;
  }

  Future<void> _showAddLogPicker(
    BuildContext context,
    WidgetRef ref,
    _RehabPageData data,
  ) async {
    final actions = data.actions;
    if (actions.isEmpty) {
      return;
    }
    final result = await showModalBottomSheet<_RehabLogEntryDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddRehabLogSheet(actions: actions),
    );
    if (result == null) {
      return;
    }

    await saveRehabLogDraft(
      ref,
      action: result.action,
      draft: result.draft,
    );
    ref.invalidate(_rehabPageDataProvider);
    _refreshRehabData(ref);

    if (!context.mounted) {
      return;
    }

    _showRehabLogSavedFeedback(context, result.action, result.draft);
  }
}

Future<RehabLogDraft?> showRehabLogSheet({
  required BuildContext context,
  required RehabAction action,
  DateTime? initialDate,
}) {
  return showModalBottomSheet<RehabLogDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => RehabLogSheet(
      action: action,
      initialDate: initialDate,
    ),
  );
}

Future<void> saveRehabLogDraft(
  WidgetRef ref, {
  required RehabAction action,
  required RehabLogDraft draft,
}) async {
  await ref.read(rehabRepositoryProvider).addLog(
        action: action,
        amount: draft.amount,
        unit: draft.unit,
        reaction: draft.reaction,
        symptomTags: draft.symptomTags,
        note: draft.note,
        createdAt: draft.createdAt,
      );
}

void refreshRehabRecordProviders(WidgetRef ref) {
  _refreshRehabData(ref);
}

void _refreshRehabData(WidgetRef ref) {
  ref.invalidate(dailyReportControllerProvider);
  ref.read(appDataRefreshProvider.notifier).state++;
}

void _showRehabLogSavedFeedback(
  BuildContext context,
  RehabAction action,
  RehabLogDraft draft,
) {
  if (draft.reaction == RehabReaction.muchWorse) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('建议减少量、暂停观察，必要时咨询医生或康复师。'),
      ),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('已记录：${action.name}')),
  );
}

class _RehabHeaderCard extends StatelessWidget {
  const _RehabHeaderCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.self_improvement_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日康复记录',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '记录今天做了什么、做了多少、做后感觉如何。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '这里是记录工具，不是康复处方。\n不舒服时可以休息。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            HeaderActionButton(
              key: const ValueKey('rehab-add-entry-button'),
              tooltip: '添加康复记录',
              onPressed: onAdd,
              icon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }
}

final _rehabPageDataProvider = FutureProvider<_RehabPageData>((ref) async {
  ref.watch(appDataRefreshProvider);
  final repository = ref.watch(rehabRepositoryProvider);
  final recoveryRepository = ref.watch(recoveryRepositoryProvider);
  final actions = await repository.loadActions();
  final todayLogs = await repository.loadToday();
  final profile = await recoveryRepository.loadProfile();
  _DailyRecoveryNoteLoadState dailyNoteState;
  try {
    dailyNoteState = _DailyRecoveryNoteLoadState.loaded(
      await recoveryRepository.loadNote(DateTime.now()),
    );
  } catch (_) {
    dailyNoteState = const _DailyRecoveryNoteLoadState.failed();
  }
  return _RehabPageData(
    actions: actions,
    todayLogs: todayLogs,
    profile: profile,
    dailyNoteState: dailyNoteState,
  );
});

class _RehabPageData {
  const _RehabPageData({
    required this.actions,
    required this.todayLogs,
    required this.profile,
    required this.dailyNoteState,
  });

  final List<RehabAction> actions;
  final List<RehabLog> todayLogs;
  final RecoveryProfile? profile;
  final _DailyRecoveryNoteLoadState dailyNoteState;

  String actionNameFor(int actionId) {
    for (final action in actions) {
      if (action.id == actionId) {
        return action.name;
      }
    }
    return legacyActionNameForId(actionId) ?? '未知活动';
  }
}

class _DailyRecoveryNoteLoadState {
  const _DailyRecoveryNoteLoadState._({
    required this.isFailed,
    this.note,
  });

  const _DailyRecoveryNoteLoadState.loaded(DailyRecoveryNote? note)
      : this._(isFailed: false, note: note);

  const _DailyRecoveryNoteLoadState.failed() : this._(isFailed: true);

  final bool isFailed;
  final DailyRecoveryNote? note;
}

class _DailyRecoveryNoteCard extends StatelessWidget {
  const _DailyRecoveryNoteCard({
    required this.noteState,
    required this.onEdit,
  });

  final _DailyRecoveryNoteLoadState noteState;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final value = noteState.note;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '每日康复小结',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              noteState.isFailed
                  ? '今日小结暂时无法读取，可稍后重试。'
                  : value == null
                      ? '用点选方式记录今天的整体感受。'
                      : '${value.overallFeeling.label} · 腰 ${value.backPainScore} · '
                          '腿 ${value.legSymptomScore} · 疲劳 ${value.fatigueScore}',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(value == null ? '记录今日小结' : '修改今日小结'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayRehabLogListCard extends StatelessWidget {
  const _TodayRehabLogListCard({required this.data});

  final _RehabPageData data;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('rehab-today-records-section'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '今天已记录',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              if (data.todayLogs.isEmpty)
                Text(
                  '今天还没有康复记录，记录一点也有价值。',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final log in data.todayLogs) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data.actionNameFor(log.actionId)),
                    subtitle: Text(
                      '${_formatNumber(log.amountValue)} ${log.unit} · ${log.reaction.label}',
                    ),
                    trailing: Text(_formatTime(log.createdAt)),
                  ),
                  if (log != data.todayLogs.last) const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRehabLogSheet extends StatefulWidget {
  const _AddRehabLogSheet({required this.actions});

  final List<RehabAction> actions;

  @override
  State<_AddRehabLogSheet> createState() => _AddRehabLogSheetState();
}

class _AddRehabLogSheetState extends State<_AddRehabLogSheet> {
  static const _symptomTagOptions = ['腰酸', '腰痛', '腿麻', '脚背刺痛', '疲劳'];

  final _noteController = TextEditingController();
  late RehabAction _action;
  late double _amount;
  late String _unit;
  late DateTime _createdAt;
  RehabReaction _reaction = RehabReaction.noChange;
  Set<String> _symptomTags = {};
  bool _isNoteExpanded = false;

  @override
  void initState() {
    super.initState();
    _action = widget.actions.first;
    _amount = 1;
    _unit = _action.defaultUnit;
    final now = DateTime.now();
    _createdAt = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = _unitOptionsFor(_action);
    if (!units.contains(_unit)) {
      _unit = units.first;
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '添加康复记录',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                key: const ValueKey('rehab-activity-dropdown'),
                initialValue: _action.id,
                decoration: const InputDecoration(labelText: '选择康复活动'),
                items: [
                  for (final action in widget.actions)
                    DropdownMenuItem(
                      value: action.id,
                      child: Text(action.name),
                    ),
                ],
                onChanged: (id) {
                  final next = _actionById(id);
                  if (next == null) return;
                  setState(() {
                    _action = next;
                    _unit = _defaultUnitFor(next);
                  });
                },
              ),
              const SizedBox(height: 8),
              _SelectedActivityInfo(action: _action),
              const SizedBox(height: 10),
              _RecordDateRow(
                createdAt: _createdAt,
                onPick: _pickDate,
              ),
              const SizedBox(height: 10),
              _AmountStepper(
                amount: _amount,
                unit: _unit,
                unitOptions: units,
                onDecrease: () => setState(() {
                  _amount =
                      (_amount - _stepForUnit(_unit)).clamp(0, 999).toDouble();
                }),
                onIncrease: () => setState(() {
                  _amount =
                      (_amount + _stepForUnit(_unit)).clamp(0, 999).toDouble();
                }),
                onUnitChanged: (unit) => setState(() => _unit = unit),
              ),
              const SizedBox(height: 10),
              Text('做完感觉？', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reaction in RehabReaction.values)
                    ChoiceChip(
                      avatar: Icon(_reactionIcon(reaction), size: 18),
                      label: Text(reaction.label),
                      selected: _reaction == reaction,
                      selectedColor: _reactionColor(reaction).withValues(
                        alpha: 0.16,
                      ),
                      onSelected: (_) => setState(() => _reaction = reaction),
                    ),
                ],
              ),
              if (_reaction == RehabReaction.muchWorse) ...[
                const SizedBox(height: 10),
                const Card(
                  color: Color(0xFFFFF1F0),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('建议减少量、暂停观察，必要时咨询医生或康复师。'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text('症状标签（可选）', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _symptomTagOptions)
                    FilterChip(
                      label: Text(tag),
                      selected: _symptomTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          _symptomTags = {..._symptomTags};
                          selected
                              ? _symptomTags.add(tag)
                              : _symptomTags.remove(tag);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _OptionalNoteField(
                controller: _noteController,
                isExpanded: _isNoteExpanded,
                onToggle: () {
                  setState(() => _isNoteExpanded = !_isNoteExpanded);
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('rehab-log-save-button'),
                    onPressed: () {
                      Navigator.of(context).pop(
                        _RehabLogEntryDraft(
                          action: _action,
                          draft: _RehabLogDraft(
                            amount: _formatAmount(_amount),
                            unit: _unit,
                            reaction: _reaction,
                            symptomTags: _symptomTags.toList(),
                            note: _noteController.text,
                            createdAt: _createdAt,
                          ),
                        ),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  RehabAction? _actionById(int? id) {
    if (id == null) return null;
    for (final action in widget.actions) {
      if (action.id == id) {
        return action;
      }
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _createdAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _createdAt.hour,
          _createdAt.minute,
        );
      });
    }
  }
}

class _RehabLogEntryDraft {
  const _RehabLogEntryDraft({
    required this.action,
    required this.draft,
  });

  final RehabAction action;
  final RehabLogDraft draft;
}

class _SelectedActivityInfo extends StatelessWidget {
  const _SelectedActivityInfo({required this.action});

  final RehabAction action;

  @override
  Widget build(BuildContext context) {
    final activity = activityForAction(action);
    if (activity == null) {
      return const SizedBox.shrink();
    }
    final phaseLabel = _phaseRangeLabel(activity);
    final patientTip = activity.patientTip.trim();
    final stopRule = activity.stopRule.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '适合阶段：$phaseLabel',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (patientTip.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(patientTip),
            ],
            if (stopRule.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(stopRule),
            ],
            if (activity.requiresDoctorClearance) ...[
              const SizedBox(height: 6),
              const Text('该活动更适合后期或专业指导下记录，请以医生或康复师建议为准。'),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordDateRow extends StatelessWidget {
  const _RecordDateRow({
    required this.createdAt,
    required this.onPick,
  });

  final DateTime createdAt;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.event_outlined, size: 18),
        const SizedBox(width: 8),
        Text(
          '记录日期',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _formatDate(createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextButton(
          onPressed: onPick,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('选择'),
        ),
      ],
    );
  }
}

class _RehabPhaseGuideCard extends StatelessWidget {
  const _RehabPhaseGuideCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('康复阶段说明'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          Text(
            _rehabPhaseGuideText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

String _phaseRangeLabel(RehabActivity activity) {
  final start = rehabPhaseTitle(activity.phaseStart);
  final end = rehabPhaseTitle(activity.phaseEnd);
  return start == end ? start : '$start-$end';
}

const _rehabPhaseGuideText =
    '本康复计划参考运动医学中的组织愈合节律构建。人体修复并非线性过程，通常会经历炎症消退、组织增生、胶原纤维重塑到功能成熟等阶段。\n\n'
    '我们将其划分为四个阶段，目的是让康复记录节奏与身体的修复节奏更好同步：\n\n'
    '第1阶段（0-4周）：急性愈合与神经唤醒。聚焦早期管理，通过轻柔活动保护受影响组织，减少早期过度负荷带来的不适。\n\n'
    '第2阶段（4-8周）：运动控制与动态稳定。针对组织增生期，重点在于通过温和运动，把零散的活动体验转化为更有序的受控力量。\n\n'
    '第3阶段（8-12周）：功能性负荷进阶。对应组织重塑成熟期，通过功能性负荷训练，逐步提升胶原纤维的承受能力，重建日常活动信心。\n\n'
    '第4阶段（12周后）：高负荷恢复。针对组织功能成熟期，由受控训练逐步过渡至自主运动，帮助回归正常生活与运动状态。\n\n'
    '这套分期体系用于提供对应的心理与行动支持，帮助你稳步找回身体的掌控感。';

Color _reactionColor(RehabReaction reaction) {
  return switch (reaction) {
    RehabReaction.moreComfortable => const Color(0xFF27AE60),
    RehabReaction.noChange => const Color(0xFF64748B),
    RehabReaction.slightlyWorse => const Color(0xFFF2994A),
    RehabReaction.muchWorse => const Color(0xFFEB5757),
  };
}

IconData _reactionIcon(RehabReaction reaction) {
  return switch (reaction) {
    RehabReaction.moreComfortable => Icons.sentiment_satisfied_outlined,
    RehabReaction.noChange => Icons.remove_circle_outline,
    RehabReaction.slightlyWorse => Icons.warning_amber_outlined,
    RehabReaction.muchWorse => Icons.error_outline,
  };
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

String _formatAmount(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

double _stepForUnit(String unit) {
  return switch (unit) {
    '分钟' || '秒' => 1,
    _ => 1,
  };
}

List<String> _unitOptionsFor(RehabAction action) {
  final units = [
    action.defaultUnit,
    ...action.optionalUnits,
  ].where((unit) => unit.trim().isNotEmpty).toSet().toList();
  return units.isEmpty ? [action.defaultUnit] : units;
}

String _defaultUnitFor(RehabAction action) {
  final units = _unitOptionsFor(action);
  return units.contains(action.defaultUnit) ? action.defaultUnit : units.first;
}

String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDate(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
}

class RehabLogSheet extends StatefulWidget {
  const RehabLogSheet({
    required this.action,
    this.initialDate,
    super.key,
  });

  final RehabAction action;
  final DateTime? initialDate;

  @override
  State<RehabLogSheet> createState() => _RehabLogSheetState();
}

class _RehabLogSheetState extends State<RehabLogSheet> {
  static const _symptomTagOptions = ['腰酸', '腰痛', '腿麻', '脚背刺痛', '疲劳'];

  final _noteController = TextEditingController();
  late double _amount;
  late String _unit;
  late DateTime _createdAt;
  RehabReaction _reaction = RehabReaction.noChange;
  Set<String> _symptomTags = {};
  bool _isNoteExpanded = false;

  @override
  void initState() {
    super.initState();
    _amount = 1;
    _unit = widget.action.defaultUnit;
    final initial = widget.initialDate ?? DateTime.now();
    final now = DateTime.now();
    _createdAt = DateTime(
      initial.year,
      initial.month,
      initial.day,
      now.hour,
      now.minute,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = _unitOptionsFor(widget.action);
    if (!units.contains(_unit)) {
      _unit = units.first;
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '记录 ${widget.action.name}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              _RecordDateRow(
                createdAt: _createdAt,
                onPick: _pickDate,
              ),
              const SizedBox(height: 12),
              _AmountStepper(
                amount: _amount,
                unit: _unit,
                unitOptions: units,
                onDecrease: () => setState(() {
                  _amount =
                      (_amount - _stepForUnit(_unit)).clamp(0, 999).toDouble();
                }),
                onIncrease: () => setState(() {
                  _amount =
                      (_amount + _stepForUnit(_unit)).clamp(0, 999).toDouble();
                }),
                onUnitChanged: (unit) => setState(() => _unit = unit),
              ),
              const SizedBox(height: 12),
              Text('做完感觉？', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reaction in RehabReaction.values)
                    ChoiceChip(
                      avatar: Icon(_reactionIcon(reaction), size: 18),
                      label: Text(reaction.label),
                      selected: _reaction == reaction,
                      selectedColor: _reactionColor(reaction).withValues(
                        alpha: 0.16,
                      ),
                      onSelected: (_) => setState(() => _reaction = reaction),
                    ),
                ],
              ),
              if (_reaction == RehabReaction.muchWorse) ...[
                const SizedBox(height: 10),
                const Card(
                  color: Color(0xFFFFF1F0),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('建议减少量、暂停观察，必要时咨询医生或康复师。'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text('症状标签（可选）', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _symptomTagOptions)
                    FilterChip(
                      label: Text(tag),
                      selected: _symptomTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          _symptomTags = {..._symptomTags};
                          selected
                              ? _symptomTags.add(tag)
                              : _symptomTags.remove(tag);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _OptionalNoteField(
                controller: _noteController,
                isExpanded: _isNoteExpanded,
                onToggle: () {
                  setState(() => _isNoteExpanded = !_isNoteExpanded);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('rehab-log-save-button'),
                    onPressed: () {
                      Navigator.of(context).pop(
                        _RehabLogDraft(
                          amount: _formatAmount(_amount),
                          unit: _unit,
                          reaction: _reaction,
                          symptomTags: _symptomTags.toList(),
                          note: _noteController.text,
                          createdAt: _createdAt,
                        ),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _createdAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _createdAt.hour,
          _createdAt.minute,
        );
      });
    }
  }
}

class _AmountStepper extends StatelessWidget {
  const _AmountStepper({
    required this.amount,
    required this.unit,
    required this.unitOptions,
    required this.onDecrease,
    required this.onIncrease,
    required this.onUnitChanged,
  });

  final double amount;
  final String unit;
  final List<String> unitOptions;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('rehab-amount-decrease'),
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: '减少完成量',
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(
              width: 72,
              child: Text(
                _formatAmount(amount),
                key: const ValueKey('rehab-amount-stepper-value'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            IconButton(
              key: const ValueKey('rehab-amount-increase'),
              onPressed: onIncrease,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '增加完成量',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            _UnitSelector(
              unit: unit,
              unitOptions: unitOptions,
              onChanged: onUnitChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({
    required this.unit,
    required this.unitOptions,
    required this.onChanged,
  });

  final String unit;
  final List<String> unitOptions;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (unitOptions.length <= 1) {
      return Text(
        unit,
        key: const ValueKey('rehab-unit-options'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: const ValueKey('rehab-unit-options'),
        value: unit,
        isDense: true,
        items: [
          for (final option in unitOptions)
            DropdownMenuItem(
              value: option,
              child: Text(option),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

class _OptionalNoteField extends StatelessWidget {
  const _OptionalNoteField({
    required this.controller,
    required this.isExpanded,
    required this.onToggle,
  });

  final TextEditingController controller;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          key: const ValueKey('optional-note-toggle'),
          onPressed: onToggle,
          icon: Icon(isExpanded ? Icons.expand_less : Icons.note_add_outlined),
          label: const Text('添加备注（可选）'),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('optional-note-field'),
            controller: controller,
            decoration: const InputDecoration(labelText: '备注（可选）'),
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}

class DailyRecoveryNoteSheet extends StatefulWidget {
  const DailyRecoveryNoteSheet({this.note, super.key});

  final DailyRecoveryNote? note;

  @override
  State<DailyRecoveryNoteSheet> createState() => _DailyRecoveryNoteSheetState();
}

class _DailyRecoveryNoteSheetState extends State<DailyRecoveryNoteSheet> {
  static const _tagOptions = ['腰酸', '腰痛', '腿麻', '脚背刺痛', '疲劳'];

  final _noteController = TextEditingController();
  late OverallFeeling _overallFeeling;
  late int _backPainScore;
  late int _legSymptomScore;
  late int _fatigueScore;
  late Set<String> _tags;
  bool _isNoteExpanded = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _overallFeeling = note?.overallFeeling ?? OverallFeeling.same;
    _backPainScore = note?.backPainScore ?? 0;
    _legSymptomScore = note?.legSymptomScore ?? 0;
    _fatigueScore = note?.fatigueScore ?? 0;
    _tags = {...?note?.tags};
    _noteController.text = note?.note ?? '';
    _isNoteExpanded = _noteController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '每日康复小结',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              Text('整体感觉', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<OverallFeeling>(
                key: const ValueKey('daily-feeling-segmented'),
                segments: const [
                  ButtonSegment(
                    value: OverallFeeling.better,
                    label: Text('好一点'),
                  ),
                  ButtonSegment(
                    value: OverallFeeling.same,
                    label: Text('差不多'),
                  ),
                  ButtonSegment(
                    value: OverallFeeling.slightlyWorse,
                    label: Text('有点加重'),
                  ),
                ],
                selected: {_overallFeeling},
                onSelectionChanged: (selected) {
                  setState(() => _overallFeeling = selected.single);
                },
              ),
              const SizedBox(height: 16),
              _ScoreSlider(
                key: const ValueKey('daily-back-pain-slider-row'),
                label: '腰部不适',
                value: _backPainScore,
                sliderKey: const ValueKey('daily-back-pain-slider'),
                onChanged: (value) => setState(() => _backPainScore = value),
              ),
              _ScoreSlider(
                key: const ValueKey('daily-leg-symptom-slider-row'),
                label: '腿部症状',
                value: _legSymptomScore,
                sliderKey: const ValueKey('daily-leg-symptom-slider'),
                onChanged: (value) => setState(() => _legSymptomScore = value),
              ),
              _ScoreSlider(
                key: const ValueKey('daily-fatigue-slider-row'),
                label: '疲劳',
                value: _fatigueScore,
                sliderKey: const ValueKey('daily-fatigue-slider'),
                onChanged: (value) => setState(() => _fatigueScore = value),
              ),
              const SizedBox(height: 12),
              Text('症状标签（可选）', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tagOptions)
                    FilterChip(
                      label: Text(tag),
                      selected: _tags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          _tags = {..._tags};
                          selected ? _tags.add(tag) : _tags.remove(tag);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _OptionalNoteField(
                controller: _noteController,
                isExpanded: _isNoteExpanded,
                onToggle: () {
                  setState(() => _isNoteExpanded = !_isNoteExpanded);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _DailyRecoveryNoteDraft(
                          overallFeeling: _overallFeeling,
                          backPainScore: _backPainScore,
                          legSymptomScore: _legSymptomScore,
                          fatigueScore: _fatigueScore,
                          tags: _tags.toList(),
                          note: _noteController.text,
                        ),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.sliderKey,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final Key sliderKey;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              '$value / 10',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        Slider(
          key: sliderKey,
          min: 0,
          max: 10,
          divisions: 10,
          value: value.toDouble(),
          label: value.toString(),
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }
}

class _DailyRecoveryNoteDraft {
  const _DailyRecoveryNoteDraft({
    required this.overallFeeling,
    required this.backPainScore,
    required this.legSymptomScore,
    required this.fatigueScore,
    required this.tags,
    required this.note,
  });

  final OverallFeeling overallFeeling;
  final int backPainScore;
  final int legSymptomScore;
  final int fatigueScore;
  final List<String> tags;
  final String note;
}

typedef _RehabLogDraft = RehabLogDraft;

class RehabLogDraft {
  const RehabLogDraft({
    required this.amount,
    required this.unit,
    required this.reaction,
    required this.symptomTags,
    required this.note,
    required this.createdAt,
  });

  final String amount;
  final String unit;
  final RehabReaction reaction;
  final List<String> symptomTags;
  final String note;
  final DateTime createdAt;
}
