import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../records/domain/activity_record.dart';
import '../../settings/data/local_data_repository.dart';
import '../application/daily_report_controller.dart';
import '../domain/daily_report.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(dailyReportControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '报告',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              tooltip: '刷新报告',
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () {
                ref.invalidate(dailyReportControllerProvider);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        reportState.when(
          loading: () => const _ReportLoading(),
          error: (error, stackTrace) => _ReportError(
            onRetry: () {
              ref.invalidate(dailyReportControllerProvider);
            },
          ),
          data: (report) => _DailyReportView(report: report),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('报告边界'),
            subtitle: Text('报告只汇总本地记录，不提供诊断、治疗建议或复发判断。'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导出数据'),
            subtitle: const Text('导出本地设置和本地记录为 JSON 文件。'),
            trailing: IconButton(
              tooltip: '导出数据',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: () => _exportLocalData(context, ref),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportLocalData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await ref.read(localDataRepositoryProvider).exportToJson();

    messenger.showSnackBar(
      SnackBar(content: Text('已导出：${file.path}')),
    );
  }
}

class _DailyReportView extends StatelessWidget {
  const _DailyReportView({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.today_outlined),
            title: const Text('今日记录总数'),
            subtitle: Text('${report.totalCount} 条本地记录'),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final type in ActivityRecordType.values)
              _ReportCountTile(
                type: type,
                count: report.countFor(type),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _LatestRecordCard(record: report.latestRecord),
      ],
    );
  }
}

class _ReportCountTile extends StatelessWidget {
  const _ReportCountTile({
    required this.type,
    required this.count,
  });

  final ActivityRecordType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_iconFor(type)),
        title: Text(type.label),
        trailing: Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

class _LatestRecordCard extends StatelessWidget {
  const _LatestRecordCard({required this.record});

  final ActivityRecord? record;

  @override
  Widget build(BuildContext context) {
    final currentRecord = record;

    if (currentRecord == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.inbox_outlined),
          title: Text('暂无今日记录'),
          subtitle: Text('在记录页添加内容后，这里会显示今日概览。'),
        ),
      );
    }

    final time =
        '${currentRecord.createdAt.hour.toString().padLeft(2, '0')}:${currentRecord.createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.update_outlined),
        title: const Text('最近一条记录'),
        subtitle: Text('$time · ${currentRecord.type.label}'),
      ),
    );
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在读取本地报告'),
      ),
    );
  }
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('报告读取失败'),
        subtitle: const Text('请稍后重试。'),
        trailing: TextButton(
          onPressed: onRetry,
          child: const Text('重试'),
        ),
      ),
    );
  }
}
