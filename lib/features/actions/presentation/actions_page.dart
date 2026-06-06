import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/application/daily_report_controller.dart';
import '../data/rehab_repository.dart';
import '../domain/action_item.dart';

class ActionsPage extends ConsumerWidget {
  const ActionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsState = ref.watch(_rehabActionsProvider);

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
            subtitle: Text('这里的动作只是记录模板，用于回顾完成量和做后反应，不作为治疗处方。'),
          ),
        ),
        const SizedBox(height: 12),
        actionsState.when(
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
                onPressed: () => ref.invalidate(_rehabActionsProvider),
                child: const Text('重试'),
              ),
            ),
          ),
          data: (actions) => Column(
            children: [
              for (final action in actions) ...[
                _RehabActionCard(
                  action: action,
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
    final result = await showDialog<_RehabLogDraft>(
      context: context,
      builder: (context) => _RehabLogDialog(action: action),
    );
    if (result == null) {
      return;
    }

    await ref.read(rehabRepositoryProvider).addLog(
          action: action,
          amount: result.amount,
          unit: result.unit,
          reaction: result.reaction,
          symptomTag: result.symptomTag,
          note: result.note,
        );
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

final _rehabActionsProvider = FutureProvider<List<RehabAction>>((ref) {
  return ref.watch(rehabRepositoryProvider).loadActions();
});

class _RehabActionCard extends StatelessWidget {
  const _RehabActionCard({
    required this.action,
    required this.onRecord,
  });

  final RehabAction action;
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

class _RehabLogDialog extends StatefulWidget {
  const _RehabLogDialog({required this.action});

  final RehabAction action;

  @override
  State<_RehabLogDialog> createState() => _RehabLogDialogState();
}

class _RehabLogDialogState extends State<_RehabLogDialog> {
  static const _symptomTags = ['腰酸', '腰痛', '臀腿痛', '腿麻', '脚背刺痛', '疲劳'];

  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  final _noteController = TextEditingController();
  RehabReaction _reaction = RehabReaction.noChange;
  String? _symptomTag;

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
    return AlertDialog(
      title: Text('记录：${widget.action.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            DropdownButtonFormField<String>(
              initialValue: _symptomTag,
              decoration: const InputDecoration(labelText: '症状标签'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('不选择'),
                ),
                for (final tag in _symptomTags)
                  DropdownMenuItem(
                    value: tag,
                    child: Text(tag),
                  ),
              ],
              onChanged: (value) {
                setState(() => _symptomTag = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '备注'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _RehabLogDraft(
                amount: _amountController.text,
                unit: _unitController.text,
                reaction: _reaction,
                symptomTag: _symptomTag,
                note: _noteController.text,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _RehabLogDraft {
  const _RehabLogDraft({
    required this.amount,
    required this.unit,
    required this.reaction,
    required this.symptomTag,
    required this.note,
  });

  final String amount;
  final String unit;
  final RehabReaction reaction;
  final String? symptomTag;
  final String note;
}
