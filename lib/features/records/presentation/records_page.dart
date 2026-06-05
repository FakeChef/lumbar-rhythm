import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/activity_records_controller.dart';
import '../domain/activity_record.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordsState = ref.watch(activityRecordsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '记录',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        _QuickRecordPanel(
          noteController: _noteController,
          onRecord: _addRecord,
        ),
        const SizedBox(height: 16),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('症状记录仅用于自我回顾'),
          subtitle: Text('这里不会进行诊断、治疗建议或复发判断。'),
        ),
        const Divider(height: 32),
        Text(
          '今日记录',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        recordsState.when(
          loading: () => const _RecordsLoading(),
          error: (error, stackTrace) => _RecordsError(
            onRetry: () {
              ref.invalidate(activityRecordsControllerProvider);
            },
          ),
          data: (records) => _TodayRecordsList(records: records),
        ),
      ],
    );
  }

  Future<void> _addRecord(ActivityRecordType type) async {
    final note = _noteController.text;
    await ref.read(activityRecordsControllerProvider.notifier).addRecord(
          type: type,
          note: note,
        );
    _noteController.clear();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已记录：${type.label}')),
    );
  }
}

class _QuickRecordPanel extends StatelessWidget {
  const _QuickRecordPanel({
    required this.noteController,
    required this.onRecord,
  });

  final TextEditingController noteController;
  final ValueChanged<ActivityRecordType> onRecord;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '快速记录',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '可选，例如：坐了很久、走动 5 分钟、主观不适感',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in ActivityRecordType.values)
                  FilledButton.tonalIcon(
                    onPressed: () => onRecord(type),
                    icon: Icon(_iconFor(type)),
                    label: Text(type.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ActivityRecordType type) {
    return switch (type) {
      ActivityRecordType.sitting => Icons.event_seat_outlined,
      ActivityRecordType.standing => Icons.accessibility_new_outlined,
      ActivityRecordType.symptom => Icons.healing_outlined,
      ActivityRecordType.stretch => Icons.directions_walk_outlined,
    };
  }
}

class _TodayRecordsList extends StatelessWidget {
  const _TodayRecordsList({required this.records});

  final List<ActivityRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.inbox_outlined),
          title: Text('暂无记录'),
          subtitle: Text('今天的本地记录会显示在这里。'),
        ),
      );
    }

    return Column(
      children: [
        for (final record in records)
          Card(
            child: ListTile(
              leading: Icon(_iconFor(record.type)),
              title: Text(record.type.label),
              subtitle: Text(_subtitleFor(record)),
            ),
          ),
      ],
    );
  }

  String _subtitleFor(ActivityRecord record) {
    final time =
        '${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}';
    final note = record.note;

    if (note == null || note.isEmpty) {
      return '$time · ${record.type.description}';
    }

    return '$time · $note';
  }

  IconData _iconFor(ActivityRecordType type) {
    return switch (type) {
      ActivityRecordType.sitting => Icons.event_seat_outlined,
      ActivityRecordType.standing => Icons.accessibility_new_outlined,
      ActivityRecordType.symptom => Icons.healing_outlined,
      ActivityRecordType.stretch => Icons.directions_walk_outlined,
    };
  }
}

class _RecordsLoading extends StatelessWidget {
  const _RecordsLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在读取今日记录'),
      ),
    );
  }
}

class _RecordsError extends StatelessWidget {
  const _RecordsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('记录读取失败'),
        subtitle: const Text('请稍后重试。'),
        trailing: TextButton(
          onPressed: onRetry,
          child: const Text('重试'),
        ),
      ),
    );
  }
}
