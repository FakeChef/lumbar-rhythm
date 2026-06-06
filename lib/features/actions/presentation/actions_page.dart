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
        Text(
          '康复记录',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('康复记录'),
            subtitle: Text('这里的动作只是记录模板，用于回顾完成量和做后反应，不代表固定方案。'),
          ),
        ),
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
              for (final action in data.actions) ...[
                _RehabActionCard(
                  action: action,
                  todayAmount: data.todayAmountFor(action),
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

  String todayAmountFor(RehabAction action) {
    final amount = todayLogs
        .where((log) => log.actionId == action.id)
        .map((log) => log.amountValue)
        .fold(0.0, (sum, value) => sum + value);
    if (amount == 0) {
      return '今日 0 ${action.defaultUnit}';
    }
    final display = amount % 1 == 0 ? amount.toInt().toString() : '$amount';
    return '今日 $display ${action.defaultUnit}';
  }
}

class _RehabActionCard extends StatelessWidget {
  const _RehabActionCard({
    required this.action,
    required this.todayAmount,
    required this.onRecord,
  });

  final RehabAction action;
  final String todayAmount;
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
              children: [
                const Icon(Icons.accessibility_new_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(action.defaultUnit),
              ],
            ),
            const SizedBox(height: 8),
            Text(action.guidance),
            const SizedBox(height: 8),
            Text(
              todayAmount,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onRecord,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RehabLogSheet extends StatefulWidget {
  const RehabLogSheet({required this.action, super.key});

  final RehabAction action;

  @override
  State<RehabLogSheet> createState() => _RehabLogSheetState();
}

class _RehabLogSheetState extends State<RehabLogSheet> {
  static const _symptomTagOptions = ['腰酸', '腰痛', '臀腿痛', '腿麻', '脚背刺痛', '疲劳'];

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
              '记录：${widget.action.name}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
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
            DropdownButtonFormField<RehabReaction>(
              initialValue: _reaction,
              decoration: const InputDecoration(labelText: '做后反应'),
              items: [
                for (final reaction in RehabReaction.values)
                  DropdownMenuItem(
                    value: reaction,
                    child: Text(reaction.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _reaction = value);
                }
              },
            ),
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
              decoration: const InputDecoration(labelText: '备注'),
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
