import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../reports/application/daily_report_controller.dart';
import '../data/rehab_repository.dart';
import '../domain/action_item.dart';

class ActionsPage extends ConsumerStatefulWidget {
  const ActionsPage({super.key});

  @override
  ConsumerState<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends ConsumerState<ActionsPage> {
  int? _selectedActionId;

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TodayRehabLogListCard(data: data),
              const SizedBox(height: 12),
              _RehabActionPickerCard(
                actions: data.actions,
                selectedActionId: _selectedActionId ?? data.actions.firstOrNull?.id,
                onChanged: (value) => setState(() => _selectedActionId = value),
                onRecord: () {
                  final selectedAction = data.actionById(
                    _selectedActionId ?? data.actions.firstOrNull?.id,
                  );
                  if (selectedAction != null) {
                    _showLogDialog(context, ref, selectedAction);
                  }
                },
              ),
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
    ref.read(appDataRefreshProvider.notifier).state++;

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
                    '今日康复记录',
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
  ref.watch(appDataRefreshProvider);
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

  RehabAction? actionById(int? actionId) {
    if (actionId == null) {
      return null;
    }
    for (final action in actions) {
      if (action.id == actionId) {
        return action;
      }
    }
    return null;
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

class _TodayRehabLogListCard extends StatelessWidget {
  const _TodayRehabLogListCard({required this.data});

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
                if (log != data.todayLogs.last) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }
}

class _RehabActionPickerCard extends StatelessWidget {
  const _RehabActionPickerCard({
    required this.actions,
    required this.selectedActionId,
    required this.onChanged,
    required this.onRecord,
  });

  final List<RehabAction> actions;
  final int? selectedActionId;
  final ValueChanged<int?> onChanged;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              key: const ValueKey('rehab-action-dropdown'),
              initialValue: selectedActionId,
              decoration: const InputDecoration(labelText: '选择康复动作'),
              items: [
                for (final action in actions)
                  DropdownMenuItem(
                    value: action.id,
                    child: Text(action.name),
                  ),
              ],
              onChanged: onChanged,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: actions.isEmpty ? null : onRecord,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('记录一次'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull {
    return isEmpty ? null : first;
  }
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

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
