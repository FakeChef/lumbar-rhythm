import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/media/gallery_image_saver.dart';
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
            title: const Text('备份数据'),
            subtitle: const Text('高级功能：导出本地 JSON，主要用于备份或问题排查。'),
            trailing: IconButton(
              tooltip: '备份数据',
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

    final savedAt = DateTime.now();
    final fileName = 'lumbar_rhythm_weekly_${_dateStamp(savedAt)}.png';
    final imageBytes = bytes.buffer.asUint8List();

    try {
      final result = await ref.read(galleryImageSaverProvider).savePng(
            bytes: imageBytes,
            fileName: fileName,
          );

      if (!mounted) {
        return;
      }

      if (result.saved) {
        messenger.showSnackBar(
          const SnackBar(content: Text('已保存到相册：Lumbar Rhythm')),
        );
        return;
      }
    } catch (_) {
      // Fall back to app documents below so the user still gets a saved image.
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(imageBytes, flush: true);

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('相册保存失败，已保存到应用目录：${file.path}')),
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
        _SevenDayTrendCard(report: report),
        const SizedBox(height: 12),
        RepaintBoundary(
          key: weeklyReportImageKey,
          child: _WeeklyReportImageCard(report: report),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('保存到相册'),
            subtitle: const Text('把最近 7 天周报保存为相册 PNG 图片。'),
            trailing: IconButton(
              tooltip: '保存到相册',
              icon: const Icon(Icons.download_outlined),
              onPressed: onSaveWeeklyImage,
            ),
          ),
        ),
      ],
    );
  }
}

class _SevenDayTrendCard extends StatelessWidget {
  const _SevenDayTrendCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final points = _dailyCounts();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '最近 7 天趋势',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _SevenDayTrendPainter(
                  points: points,
                  lineColor: Theme.of(context).colorScheme.primary,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                  axisColor: Theme.of(context).colorScheme.outlineVariant,
                  textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '趋势只反映记录频率，不能代表疼痛程度或康复效果。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<_TrendPoint> _dailyCounts() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final counts = {
      for (var index = 0; index < 7; index++)
        start.add(Duration(days: index)): 0,
    };

    for (final record in report.recentRecords) {
      final day = DateTime(
        record.createdAt.year,
        record.createdAt.month,
        record.createdAt.day,
      );
      if (counts.containsKey(day)) {
        counts[day] = counts[day]! + 1;
      }
    }

    return [
      for (final entry in counts.entries)
        _TrendPoint(
          label: '${entry.key.month}/${entry.key.day}',
          count: entry.value,
        ),
    ];
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
              SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: _SevenDayTrendPainter(
                    points: _dailyCounts(),
                    lineColor: Theme.of(context).colorScheme.primary,
                    fillColor: Theme.of(context).colorScheme.primaryContainer,
                    axisColor: Theme.of(context).colorScheme.outlineVariant,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
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

  List<_TrendPoint> _dailyCounts() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final counts = {
      for (var index = 0; index < 7; index++)
        start.add(Duration(days: index)): 0,
    };

    for (final record in report.recentRecords) {
      final day = DateTime(
        record.createdAt.year,
        record.createdAt.month,
        record.createdAt.day,
      );
      if (counts.containsKey(day)) {
        counts[day] = counts[day]! + 1;
      }
    }

    return [
      for (final entry in counts.entries)
        _TrendPoint(
          label: '${entry.key.month}/${entry.key.day}',
          count: entry.value,
        ),
    ];
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

class _TrendPoint {
  const _TrendPoint({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class _SevenDayTrendPainter extends CustomPainter {
  const _SevenDayTrendPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.axisColor,
    required this.textColor,
  });

  final List<_TrendPoint> points;
  final Color lineColor;
  final Color fillColor;
  final Color axisColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 16.0;
    const bottomPadding = 34.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - leftPadding - rightPadding;
    final maxCount = points
        .map((point) => point.count)
        .fold<int>(1, (max, count) => count > max ? count : max);
    final stepX = points.length == 1 ? 0.0 : chartWidth / (points.length - 1);
    final coordinates = [
      for (var index = 0; index < points.length; index++)
        Offset(
          leftPadding + stepX * index,
          topPadding +
              chartHeight * (1 - (points[index].count / maxCount).clamp(0, 1)),
        ),
    ];

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = topPadding + chartHeight * index / 3;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        axisPaint,
      );
    }

    final fillPath = Path()
      ..moveTo(coordinates.first.dx, topPadding + chartHeight);
    for (final coordinate in coordinates) {
      fillPath.lineTo(coordinate.dx, coordinate.dy);
    }
    fillPath.lineTo(coordinates.last.dx, topPadding + chartHeight);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()..color = fillColor.withValues(alpha: 0.45),
    );

    final linePath = Path()..moveTo(coordinates.first.dx, coordinates.first.dy);
    for (final coordinate in coordinates.skip(1)) {
      linePath.lineTo(coordinate.dx, coordinate.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = lineColor;
    for (var index = 0; index < coordinates.length; index++) {
      final coordinate = coordinates[index];
      canvas.drawCircle(coordinate, 5, dotPaint);
      _drawCenteredText(
        canvas,
        points[index].count.toString(),
        Offset(coordinate.dx, coordinate.dy - 22),
        11,
      );
      _drawCenteredText(
        canvas,
        points[index].label,
        Offset(coordinate.dx, size.height - 12),
        10,
      );
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
  ) {
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: fontSize,
    );
    final textStyle = ui.TextStyle(color: textColor, fontSize: fontSize);
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 48));
    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - 24, center.dy - paragraph.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SevenDayTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.textColor != textColor;
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
