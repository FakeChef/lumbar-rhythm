import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/application/daily_report_controller.dart';
import '../application/activity_records_controller.dart';
import '../domain/activity_record.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  ActivityRecordType? _selectedFilter;
  String _searchText = '';

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordsState = ref.watch(activityRecordsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '旧版记录（兼容）',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              tooltip: '刷新记录',
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () {
                ref.invalidate(activityRecordsControllerProvider);
              },
            ),
          ],
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
          title: Text('旧版记录（兼容）'),
          subtitle: Text('这里只保留旧数据的查看和兼容记录，新主流程请使用康复页。'),
        ),
        const Divider(height: 32),
        Text(
          '今日记录',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_outlined),
            suffixIcon: _searchText.isEmpty
                ? null
                : IconButton(
                    tooltip: '清除搜索',
                    icon: const Icon(Icons.close_outlined),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchText = '');
                    },
                  ),
            labelText: '搜索备注',
            hintText: '输入关键词筛选今日记录',
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _searchText = value.trim());
          },
        ),
        const SizedBox(height: 12),
        _RecordFilterChips(
          selectedFilter: _selectedFilter,
          onSelected: (type) {
            setState(() {
              _selectedFilter = type;
            });
          },
        ),
        const SizedBox(height: 8),
        recordsState.when(
          loading: () => const _RecordsLoading(),
          error: (error, stackTrace) => _RecordsError(
            onRetry: () {
              ref.invalidate(activityRecordsControllerProvider);
            },
          ),
          data: (records) => _TodayRecordsList(
            records: _filteredRecords(records),
            selectedFilter: _selectedFilter,
            searchText: _searchText,
            onDelete: _deleteRecord,
          ),
        ),
      ],
    );
  }

  List<ActivityRecord> _filteredRecords(List<ActivityRecord> records) {
    final selectedFilter = _selectedFilter;
    final searchText = _searchText.toLowerCase();

    return records.where((record) {
      final matchesType =
          selectedFilter == null || record.type == selectedFilter;
      final note = record.note?.toLowerCase() ?? '';
      final matchesSearch = searchText.isEmpty ||
          note.contains(searchText) ||
          record.type.label.toLowerCase().contains(searchText);

      return matchesType && matchesSearch;
    }).toList();
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
    ref.invalidate(dailyReportControllerProvider);
  }

  Future<void> _deleteRecord(ActivityRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除这条记录？'),
          content: Text('将删除：${record.type.label}。此操作只影响本机数据。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(activityRecordsControllerProvider.notifier)
        .deleteRecord(record.id);
    ref.invalidate(dailyReportControllerProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除记录')),
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

class _RecordFilterChips extends StatelessWidget {
  const _RecordFilterChips({
    required this.selectedFilter,
    required this.onSelected,
  });

  final ActivityRecordType? selectedFilter;
  final ValueChanged<ActivityRecordType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          selected: selectedFilter == null,
          label: const Text('全部'),
          onSelected: (_) => onSelected(null),
        ),
        for (final type in ActivityRecordType.values)
          FilterChip(
            selected: selectedFilter == type,
            label: Text(type.label),
            onSelected: (_) => onSelected(type),
          ),
      ],
    );
  }
}

class _TodayRecordsList extends StatelessWidget {
  const _TodayRecordsList({
    required this.records,
    required this.selectedFilter,
    required this.searchText,
    required this.onDelete,
  });

  final List<ActivityRecord> records;
  final ActivityRecordType? selectedFilter;
  final String searchText;
  final ValueChanged<ActivityRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      final hasFilter = selectedFilter != null || searchText.isNotEmpty;

      return Card(
        child: ListTile(
          leading: const Icon(Icons.inbox_outlined),
          title: Text(hasFilter ? '暂无筛选结果' : '暂无记录'),
          subtitle: const Text('今天的本地记录会显示在这里。'),
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
              trailing: IconButton(
                tooltip: '删除记录',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(record),
              ),
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
