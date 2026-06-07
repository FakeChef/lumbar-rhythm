import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/application/daily_report_controller.dart';
import '../data/rehab_repository.dart';
import '../domain/action_item.dart';

class ActionsPage extends ConsumerWidget {
  const ActionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageState = ref.watch(_rehabPageDataProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _RehabHeaderCard(),
        const SizedBox(height: 12),
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
            children: [
              _TodayRehabSummaryCard(data: data),
              const SizedBox(height: 12),
              for (final action in data.actions) ...[
                _RehabActionCard(
                  action: action,
                  todayProgress: data.todayProgressFor(action),
                  latestReaction: data.majorityReactionFor(action),
                  onRecord: () => _showLogDialog(context, ref, action),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showLogDialog(
    BuildContext context,
    WidgetRef ref,
    RehabAction action,
  ) async {
    final result = await showModalBottomSheet<_RehabLogDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RehabLogSheet(action: action),
    );
    if (result == null) {
      return;
    }

    await ref.read(rehabRepositoryProvider).addLog(
          action: action,
          amount: result.amount,
          unit: result.unit,
          reaction: result.reaction,
          symptomTags: result.symptomTags,
          note: result.note,
        );
    ref.invalidate(_rehabPageDataProvider);
    ref.invalidate(dailyReportControllerProvider);

    if (!context.mounted) {
      return;
    }

    if (result.reaction == RehabReaction.muchWorse) {
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
}

class _RehabHeaderCard extends StatelessWidget {
  const _RehabHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFEAF6FD),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.self_improvement_outlined,
              color: Color(0xFF2E86C1),
              size: 34,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '康复记录',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF1F2937),
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
          ],
        ),
      ),
    );
  }
}

final _rehabPageDataProvider = FutureProvider<_RehabPageData>((ref) async {
  final repository = ref.watch(rehabRepositoryProvider);
  final actions = await repository.loadActions();
  final todayLogs = await repository.loadToday();
  return _RehabPageData(actions: actions, todayLogs: todayLogs);
});

class _RehabPageData {
  const _RehabPageData({
    required this.actions,
    required this.todayLogs,
  });

  final List<RehabAction> actions;
  final List<RehabLog> todayLogs;

  _ActionProgress todayProgressFor(RehabAction action) {
    final amount = todayLogs
        .where((log) => log.actionId == action.id)
        .map((log) => log.amountValue)
        .fold(0.0, (sum, value) => sum + value);
    return _ActionProgress(
      amount: amount,
      target: _defaultTargetFor(action),
      unit: action.defaultUnit,
    );
  }

  RehabReaction? majorityReactionFor(RehabAction action) {
    final logs = todayLogs.where((log) => log.actionId == action.id).toList();
    if (logs.isEmpty) {
      return null;
    }
    final counts = {
      for (final reaction in RehabReaction.values)
        reaction: logs.where((log) => log.reaction == reaction).length,
    };
    return counts.entries.reduce((left, right) {
      return left.value >= right.value ? left : right;
    }).key;
  }

  int get totalCount => todayLogs.length;

  double get walkingMinutes {
    return todayLogs
        .where((log) => actionNameFor(log.actionId) == '步行')
        .map((log) => log.amountValue)
        .fold(0.0, (sum, value) => sum + value);
  }

  int get muchWorseCount {
    return todayLogs
        .where((log) => log.reaction == RehabReaction.muchWorse)
        .length;
  }

  String actionNameFor(int actionId) {
    for (final action in actions) {
      if (action.id == actionId) {
        return action.name;
      }
    }
    return '';
  }
}

class _ActionProgress {
  const _ActionProgress({
    required this.amount,
    required this.target,
    required this.unit,
  });

  final double amount;
  final double target;
  final String unit;

  String get label {
    return '今日 ${_formatNumber(amount)} / ${_formatNumber(target)} $unit';
  }
}

class _RehabActionCard extends StatelessWidget {
  const _RehabActionCard({
    required this.action,
    required this.todayProgress,
    required this.latestReaction,
    required this.onRecord,
  });

  final RehabAction action;
  final _ActionProgress todayProgress;
  final RehabReaction? latestReaction;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_actionIcon(action), color: const Color(0xFF2E86C1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        todayProgress.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF2E86C1),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('记录'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '默认目标：${_formatNumber(todayProgress.target)} ${todayProgress.unit}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (latestReaction != null) ...[
              const SizedBox(height: 8),
              _ReactionBadge(reaction: latestReaction!),
            ],
            const SizedBox(height: 8),
            Text(
              action.guidance,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayRehabSummaryCard extends StatelessWidget {
  const _TodayRehabSummaryCard({required this.data});

  final _RehabPageData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '今日完成',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: '动作记录',
                    value: '${data.totalCount}次',
                    color: const Color(0xFF27AE60),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryMetric(
                    label: '步行',
                    value: '${_formatNumber(data.walkingMinutes)}分钟',
                    color: const Color(0xFF27AE60),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryMetric(
                    label: '明显加重',
                    value: '${data.muchWorseCount}次',
                    color: const Color(0xFFEB5757),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  const _ReactionBadge({required this.reaction});

  final RehabReaction reaction;

  @override
  Widget build(BuildContext context) {
    final color = _reactionColor(reaction);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_reactionIcon(reaction), size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '做后记录多数为：${reaction.label}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _actionIcon(RehabAction action) {
  return switch (action.name) {
    '步行' => Icons.directions_walk_outlined,
    '室内慢走' => Icons.directions_walk_outlined,
    '腹式呼吸' => Icons.air_outlined,
    '肩胛后收' => Icons.accessibility_new_outlined,
    '坐站转换' => Icons.sync_alt_outlined,
    '仰卧放松' => Icons.hotel_outlined,
    '腹横肌轻收紧' => Icons.center_focus_strong_outlined,
    'Bird-dog 简化版' => Icons.fitness_center_outlined,
    '侧桥简化版' => Icons.straighten_outlined,
    '一脚垫高放松站姿' => Icons.accessibility_new_outlined,
    _ => Icons.self_improvement_outlined,
  };
}

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

double _defaultTargetFor(RehabAction action) {
  return switch (action.name) {
    '步行' => 20,
    '室内慢走' => 10,
    '腹式呼吸' => 10,
    '肩胛后收' => 10,
    '坐站转换' => 10,
    '仰卧放松' => 10,
    '腹横肌轻收紧' => 10,
    'Bird-dog 简化版' => 2,
    '侧桥简化版' => 20,
    '一脚垫高放松站姿' => 5,
    _ => 1,
  };
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

class _QuickAmount {
  const _QuickAmount(this.amount, this.unit);

  final String amount;
  final String unit;

  String get label => '$amount$unit';
}

List<_QuickAmount> _quickAmountsFor(RehabAction action) {
  return switch (action.name) {
    '步行' => const [
        _QuickAmount('3', '分钟'),
        _QuickAmount('5', '分钟'),
        _QuickAmount('10', '分钟'),
      ],
    '室内慢走' => const [
        _QuickAmount('3', '分钟'),
        _QuickAmount('5', '分钟'),
        _QuickAmount('10', '分钟'),
      ],
    '腹式呼吸' => const [
        _QuickAmount('5', '次'),
        _QuickAmount('10', '次'),
      ],
    '坐站转换' => const [
        _QuickAmount('5', '次'),
        _QuickAmount('10', '次'),
      ],
    '仰卧放松' => const [
        _QuickAmount('5', '分钟'),
        _QuickAmount('10', '分钟'),
      ],
    'Bird-dog 简化版' => const [
        _QuickAmount('1', '组'),
        _QuickAmount('2', '组'),
      ],
    '侧桥简化版' => const [
        _QuickAmount('10', '秒'),
        _QuickAmount('20', '秒'),
      ],
    _ => [
        _QuickAmount('1', action.defaultUnit),
        _QuickAmount('5', action.defaultUnit),
      ],
  };
}

class RehabLogSheet extends StatefulWidget {
  const RehabLogSheet({required this.action, super.key});

  final RehabAction action;

  @override
  State<RehabLogSheet> createState() => _RehabLogSheetState();
}

class _RehabLogSheetState extends State<RehabLogSheet> {
  static const _symptomTagOptions = ['腰酸', '腰痛', '腿麻', '脚背刺痛', '疲劳'];

  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  final _noteController = TextEditingController();
  RehabReaction _reaction = RehabReaction.noChange;
  Set<String> _symptomTags = {};

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '1');
    _unitController = TextEditingController(text: widget.action.defaultUnit);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _unitController.dispose();
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
                '记录 ${widget.action.name}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              Text('完成了多少？', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final quick in _quickAmountsFor(widget.action))
                    ChoiceChip(
                      label: Text(quick.label),
                      selected: _amountController.text == quick.amount &&
                          _unitController.text == quick.unit,
                      onSelected: (_) {
                        setState(() {
                          _amountController.text = quick.amount;
                          _unitController.text = quick.unit;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: '完成量'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: '单位'),
                    ),
                  ),
                ],
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
                    padding: EdgeInsets.all(12),
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
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: '备注（可选）'),
                maxLines: 2,
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
                        _RehabLogDraft(
                          amount: _amountController.text,
                          unit: _unitController.text,
                          reaction: _reaction,
                          symptomTags: _symptomTags.toList(),
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

class _RehabLogDraft {
  const _RehabLogDraft({
    required this.amount,
    required this.unit,
    required this.reaction,
    required this.symptomTags,
    required this.note,
  });

  final String amount;
  final String unit;
  final RehabReaction reaction;
  final List<String> symptomTags;
  final String note;
}
