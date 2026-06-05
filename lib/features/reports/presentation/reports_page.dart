import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../records/domain/activity_record.dart';
import '../../settings/data/local_data_repository.dart';
import '../application/daily_report_controller.dart';
import '../domain/daily_report.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final _weeklyReportImageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
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
          data: (report) => _DailyReportView(
            report: report,
            weeklyReportImageKey: _weeklyReportImageKey,
            onSaveWeeklyImage: _saveWeeklyReportImage,
          ),
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

  Future<void> _saveWeeklyReportImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final boundary = _weeklyReportImageKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;

    if (boundary == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('周报图片尚未准备好，请稍后重试')),
      );
      return;
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('周报图片生成失败，请稍后重试')),
      );
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final savedAt = DateTime.now();
    final file = File(
      p.join(directory.path, 'lumbar_rhythm_weekly_${_dateStamp(savedAt)}.png'),
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('已保存周报图片：${file.path}')),
    );
  }

  String _dateStamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');

    return '$year$month${day}_$hour$minute$second';
  }
}

class _DailyReportView extends StatelessWidget {
  const _DailyReportView({
    required this.report,
    required this.weeklyReportImageKey,
    required this.onSaveWeeklyImage,
  });

  final DailyReport report;
  final GlobalKey weeklyReportImageKey;
  final VoidCallback onSaveWeeklyImage;

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
        const SizedBox(height: 12),
        RepaintBoundary(
          key: weeklyReportImageKey,
          child: _WeeklyReportImageCard(report: report),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('保存周报图片'),
            subtitle: const Text('把最近 7 天汇总保存为本地 PNG 图片。'),
            trailing: IconButton(
              tooltip: '保存周报图片',
              icon: const Icon(Icons.download_outlined),
              onPressed: onSaveWeeklyImage,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyReportImageCard extends StatelessWidget {
  const _WeeklyReportImageCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.date_range_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '腰椎节奏周报',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('最近 7 天本地记录汇总'),
              const Divider(height: 28),
              _WeeklyMetricRow(
                label: '总记录',
                value: '${report.recentTotalCount} 条',
              ),
              const SizedBox(height: 8),
              _WeeklyMetricRow(
                label: '有记录的天数',
                value: '${report.activeDaysCount()} 天',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in ActivityRecordType.values)
                    Chip(
                      avatar: Icon(_iconFor(type), size: 18),
                      label:
                          Text('${type.label} ${report.recentCountFor(type)}'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '仅用于自我回顾，不提供诊断、治疗建议或复发判断。',
                style: TextStyle(fontSize: 12),
              ),
            ],
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

class _WeeklyMetricRow extends StatelessWidget {
  const _WeeklyMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
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
