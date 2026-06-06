import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recovery_milestone_repository.dart';
import '../domain/recovery_milestone.dart';

final _milestonesProvider =
    FutureProvider.autoDispose<List<RecoveryMilestone>>((ref) {
  return ref.watch(recoveryMilestoneRepositoryProvider).loadMilestones();
});

class MilestonesPage extends ConsumerWidget {
  const MilestonesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_milestonesProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '康复节点',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            IconButton(
              tooltip: '新增节点',
              icon: const Icon(Icons.add_outlined),
              onPressed: () => _showAddDialog(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('节点只用于记录'),
            subtitle: Text('这些节点用于整理复诊、复工复学和阶段回顾备注，不代表医学恢复结论。'),
          ),
        ),
        const SizedBox(height: 12),
        state.when(
          loading: () => const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('正在读取康复节点'),
            ),
          ),
          error: (error, stackTrace) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('康复节点读取失败'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(_milestonesProvider),
                child: const Text('重试'),
              ),
            ),
          ),
          data: (milestones) => Column(
            children: [
              for (final milestone in milestones)
                _MilestoneTile(
                  milestone: milestone,
                  onComplete: () async {
                    await ref
                        .read(recoveryMilestoneRepositoryProvider)
                        .complete(milestone.id, note: milestone.note);
                    ref.invalidate(_milestonesProvider);
                  },
                  onPostpone: () =>
                      _showPostponeDialog(context, ref, milestone),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    var title = '';
    var note = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增康复节点'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: '节点名称'),
                onChanged: (value) => title = value,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: '备注（可选）'),
                onChanged: (value) => note = value,
              ),
            ],
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
    if (saved != true) return;

    await ref.read(recoveryMilestoneRepositoryProvider).addCustom(
          title: title,
          note: note,
        );
    ref.invalidate(_milestonesProvider);
  }

  Future<void> _showPostponeDialog(
    BuildContext context,
    WidgetRef ref,
    RecoveryMilestone milestone,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: milestone.targetDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;

    await ref
        .read(recoveryMilestoneRepositoryProvider)
        .postpone(milestone.id, picked, note: milestone.note);
    ref.invalidate(_milestonesProvider);
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.onComplete,
    required this.onPostpone,
  });

  final RecoveryMilestone milestone;
  final VoidCallback onComplete;
  final VoidCallback onPostpone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          milestone.isCompleted
              ? Icons.check_circle_outline
              : Icons.flag_outlined,
        ),
        title: Text(milestone.title),
        subtitle: Text(_subtitle),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'complete') {
              onComplete();
            } else if (value == 'postpone') {
              onPostpone();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'complete', child: Text('标记完成')),
            PopupMenuItem(value: 'postpone', child: Text('推迟到日期')),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = [
      milestone.category,
      milestone.isBuiltin ? '内置模板' : '自定义',
      milestone.isCompleted ? '已完成' : '计划中',
      if (milestone.targetDate != null)
        '目标 ${_formatDate(milestone.targetDate!)}',
      if (milestone.completedAt != null)
        '完成 ${_formatDate(milestone.completedAt!)}',
    ];
    return parts.join(' · ');
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
