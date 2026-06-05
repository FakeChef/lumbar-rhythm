import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../records/application/activity_records_controller.dart';
import '../../records/domain/activity_record.dart';
import '../domain/action_item.dart';

class ActionsPage extends ConsumerWidget {
  const ActionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '动作',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('温和活动提示'),
            subtitle: Text('动作仅用于久坐久站后的轻量活动提醒；如果疼痛明显加重，应停止并及时咨询专业人员。'),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in actionLibrary) ...[
          _ActionItemCard(
            item: item,
            onCompleted: () => _markCompleted(context, ref, item),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _markCompleted(
    BuildContext context,
    WidgetRef ref,
    ActionItem item,
  ) async {
    await ref.read(activityRecordsControllerProvider.notifier).addRecord(
          type: ActivityRecordType.stretch,
          note: '完成动作：${item.name}',
        );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已记录：${item.name}')),
    );
  }
}

class _ActionItemCard extends StatelessWidget {
  const _ActionItemCard({
    required this.item,
    required this.onCompleted,
  });

  final ActionItem item;
  final VoidCallback onCompleted;

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
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(item.duration),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.instructions),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onCompleted,
                icon: const Icon(Icons.check_outlined),
                label: const Text('已完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
