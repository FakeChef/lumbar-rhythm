import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/gallery_image_saver.dart';
import '../../../core/widgets/header_action_button.dart';
import '../../actions/domain/action_item.dart';
import '../application/daily_report_controller.dart';
import '../domain/daily_report.dart';
import 'report_chart_axis.dart';

const reportDisclaimerText = '本报告仅用于个人康复记录回顾，不作为专业判断依据。';

typedef ReportPngCapture = Future<Uint8List> Function(
  GlobalKey repaintBoundaryKey,
);

final reportPngCaptureProvider = Provider<ReportPngCapture>(
  (ref) => captureReportPng,
);

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final _reportBoundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(dailyReportControllerProvider);
    final period = ref.watch(reportPeriodProvider);
    final canSaveReport = reportState.asData != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '康复报告',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '回顾你的康复动作记录和阶段活动',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            HeaderActionButton(
              key: const ValueKey('report-save-button'),
              icon: Icons.save_alt_outlined,
              tooltip: '保存当前报告到相册',
              onPressed:
                  canSaveReport ? () => _saveReportToGallery(period) : null,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SegmentedButton<ReportPeriod>(
          segments: [
            for (final value in ReportPeriod.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {period},
          onSelectionChanged: (values) {
            ref.read(reportPeriodProvider.notifier).state = values.single;
          },
        ),
        const SizedBox(height: 20),
        reportState.when(
          loading: () => const _ReportLoading(),
          error: (error, stackTrace) => _ReportError(
            onRetry: () => ref.invalidate(dailyReportControllerProvider),
          ),
          data: (report) => _ReportContent(
            report: report,
            period: period,
            repaintBoundaryKey: _reportBoundaryKey,
          ),
        ),
      ],
    );
  }

  Future<void> _saveReportToGallery(ReportPeriod period) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(reportPngCaptureProvider)(
        _reportBoundaryKey,
      );
      final result = await ref.read(galleryImageSaverProvider).savePng(
            bytes: bytes,
            fileName:
                'lumbar-rhythm-report-${period.name}-${DateTime.now().millisecondsSinceEpoch}.png',
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.saved
                ? '已保存当前报告到相册：Pictures/Lumbar Rhythm'
                : '保存当前报告失败，请稍后重试。',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('保存当前报告失败，请稍后重试。')),
      );
    }
  }
}

Future<Uint8List> captureReportPng(GlobalKey repaintBoundaryKey) async {
  await WidgetsBinding.instance.endOfFrame;
  final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('Report image is not ready.');
  }
  final image = await boundary.toImage(pixelRatio: 3);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('Failed to encode report image.');
  }
  return byteData.buffer.asUint8List();
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.report,
    required this.period,
    required this.repaintBoundaryKey,
  });

  final DailyReport report;
  final ReportPeriod period;
  final GlobalKey repaintBoundaryKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            if (period == ReportPeriod.day) ...[
              _DailyRehabLogSection(report: report),
              const SizedBox(height: 20),
            ] else ...[
              _ActivityTrendReportSection(
                report: report,
                period: period,
                days: period == ReportPeriod.week ? 7 : 30,
              ),
              const SizedBox(height: 20),
            ],
            const _ShortDisclaimerText(),
          ],
        ),
      ),
    );
  }
}

class _DailyRehabLogSection extends StatelessWidget {
  const _DailyRehabLogSection({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final postSurgeryDay = report.postSurgeryDay(DateTime.now());
    final logs = [...report.rehabLogs]
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

    return KeyedSubtree(
      key: const ValueKey('rehab-report-daily-section'),
      child: _ReportSection(
        icon: Icons.today_outlined,
        title: '今日康复动作记录',
        subtitle: postSurgeryDay == null
            ? '可在设置中补充手术日期，也可以继续跳过'
            : '术后第 $postSurgeryDay 天',
        child: logs.isEmpty
            ? const _EmptyHint(text: '今天还没有康复动作记录。')
            : Column(
                children: [
                  for (final log in logs) ...[
                    _RehabLogTile(report: report, log: log),
                    if (log != logs.last) const Divider(height: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ActivityTrendReportSection extends StatelessWidget {
  const _ActivityTrendReportSection({
    required this.report,
    required this.period,
    required this.days,
  });

  final DailyReport report;
  final ReportPeriod period;
  final int days;

  @override
  Widget build(BuildContext context) {
    final trends = _activityTrends(report, days);
    final title = days == 7 ? '最近 7 天按活动趋势' : '最近 30 天按活动趋势';

    return KeyedSubtree(
      key: ValueKey(period == ReportPeriod.week
          ? 'rehab-report-week-section'
          : 'rehab-report-month-section'),
      child: _ReportSection(
        icon: Icons.bar_chart_outlined,
        title: title,
        subtitle: '按实际记录过的康复活动查看趋势',
        child: trends.isEmpty
            ? const _EmptyHint(
                text: '这段时间还没有康复活动记录。请先在康复页记录一次康复活动，周报/月报会按活动生成趋势图。',
              )
            : Column(
                children: [
                  for (final trend in trends) ...[
                    _RehabActivityTrendSection(trend: trend, days: days),
                    if (trend != trends.last) const SizedBox(height: 16),
                  ],
                ],
              ),
      ),
    );
  }
}

class _RehabActivityTrendSection extends StatelessWidget {
  const _RehabActivityTrendSection({
    required this.trend,
    required this.days,
  });

  final _ActivityTrend trend;
  final int days;

  @override
  Widget build(BuildContext context) {
    final maxValue = trend.days.fold<double>(
      0,
      (max, day) => day.value > max ? day.value : max,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              trend.action.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            _MetricRow(label: '总记录次数', value: '${trend.totalCount} 次'),
            _MetricRow(
              label: '总完成量',
              value: '${_formatNumber(trend.totalAmount)} ${trend.unit}',
            ),
            KeyedSubtree(
              key: ValueKey('rehab-activity-trend-chart-${trend.action.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RehabActivityBarChart(
                    days: trend.days,
                    maxValue: maxValue,
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

class _RehabActivityBarChart extends StatelessWidget {
  const _RehabActivityBarChart({
    required this.days,
    required this.maxValue,
  });

  final List<_ActivityTrendDay> days;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: _RehabActivityBar(
                        day: day,
                        maxValue: maxValue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _RehabActivityDateAxis(days: days),
        ],
      ),
    );
  }
}

class _RehabActivityDateAxis extends StatelessWidget {
  const _RehabActivityDateAxis({required this.days});

  final List<_ActivityTrendDay> days;

  @override
  Widget build(BuildContext context) {
    final tickIndexes = buildActivityTrendTickIndexes(
      days: [
        for (final day in days)
          ActivityTrendAxisDay(
            date: day.day,
            hasActivity: day.value > 0,
          ),
      ],
    );
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const labelWidth = 44.0;
          final availableWidth = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final index in tickIndexes)
                Positioned(
                  left: activityTrendTickLabelLeft(
                    index: index,
                    dayCount: days.length,
                    availableWidth: availableWidth,
                    labelWidth: labelWidth,
                  ),
                  width: labelWidth,
                  child: Text(
                    formatActivityTrendTickLabel(days[index].day),
                    key: ValueKey(
                      'rehab-trend-date-${days[index].day.year}-${days[index].day.month}-${days[index].day.day}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RehabActivityBar extends StatelessWidget {
  const _RehabActivityBar({
    required this.day,
    required this.maxValue,
  });

  final _ActivityTrendDay day;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final value = day.value;
    final heightFactor =
        maxValue == 0 ? 0.04 : (value / maxValue).clamp(0.04, 1.0).toDouble();
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumHeight = value == 0 ? 4.0 : 18.0;
        final height = (constraints.maxHeight * heightFactor).clamp(
          minimumHeight,
          constraints.maxHeight,
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ColoredBox(
                color: value == 0
                    ? scheme.outlineVariant.withValues(alpha: 0.55)
                    : scheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RehabLogTile extends StatelessWidget {
  const _RehabLogTile({
    required this.report,
    required this.log,
  });

  final DailyReport report;
  final RehabLog log;

  @override
  Widget build(BuildContext context) {
    final tags = log.symptomTags.isEmpty ? '无标签' : log.symptomTags.join('、');
    final note = log.note?.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_actionNameFor(report, log.actionId)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${_formatNumber(log.amountValue)} ${log.unit} · ${log.reaction.label}'),
          Text('症状标签：$tags'),
          if (note != null && note.isNotEmpty) Text('备注：$note'),
        ],
      ),
      trailing: Text(_formatClock(log.createdAt)),
    );
  }
}

class _ShortDisclaimerText extends StatelessWidget {
  const _ShortDisclaimerText();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        reportDisclaimerText,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notes_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();

  @override
  Widget build(BuildContext context) {
    return const _ReportSection(
      icon: Icons.hourglass_empty_outlined,
      title: '正在读取报告',
      subtitle: '本地数据',
      child: LinearProgressIndicator(),
    );
  }
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      icon: Icons.error_outline,
      title: '报告读取失败',
      subtitle: '请稍后重试',
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('重试'),
        ),
      ),
    );
  }
}

List<_ActivityTrend> _activityTrends(DailyReport report, int days) {
  final actionsById = {
    for (final action in report.rehabActions) action.id: action,
  };
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: days - 1));
  final end = today.add(const Duration(days: 1));
  final logsInRange = report.rehabLogs.where((log) {
    return !log.createdAt.isBefore(start) && log.createdAt.isBefore(end);
  }).toList();
  final amountsByActionAndDate = <int, Map<DateTime, double>>{};
  final countsByAction = <int, int>{};
  final totalsByAction = <int, double>{};
  final latestLogByAction = <int, DateTime>{};
  final unitsByAction = <int, String>{};

  for (final log in logsInRange) {
    final day = DateTime(
      log.createdAt.year,
      log.createdAt.month,
      log.createdAt.day,
    );
    final amount = _amountForLog(log);
    final actionAmounts = amountsByActionAndDate.putIfAbsent(
      log.actionId,
      () => <DateTime, double>{},
    );
    actionAmounts[day] = (actionAmounts[day] ?? 0) + amount;
    countsByAction[log.actionId] = (countsByAction[log.actionId] ?? 0) + 1;
    totalsByAction[log.actionId] = (totalsByAction[log.actionId] ?? 0) + amount;

    final latest = latestLogByAction[log.actionId];
    if (latest == null || log.createdAt.isAfter(latest)) {
      latestLogByAction[log.actionId] = log.createdAt;
    }
    unitsByAction.putIfAbsent(log.actionId, () => _unitForLogAmount(log));
  }

  final trends = <_ActivityTrend>[];
  for (final actionId in amountsByActionAndDate.keys) {
    final dailyAmounts = amountsByActionAndDate[actionId] ?? {};
    trends.add(
      _ActivityTrend(
        action: actionsById[actionId] ??
            RehabAction(
              id: actionId,
              name: legacyActionNameForId(actionId) ?? '未知活动',
              defaultUnit: '次',
              guidance: '',
            ),
        unit: unitsByAction[actionId] ?? '次',
        totalCount: countsByAction[actionId] ?? 0,
        totalAmount: totalsByAction[actionId] ?? 0,
        latestLogAt: latestLogByAction[actionId],
        days: [
          for (var index = 0; index < days; index++)
            _ActivityTrendDay(
              day: start.add(Duration(days: index)),
              value: dailyAmounts[start.add(Duration(days: index))] ?? 0,
            ),
        ],
      ),
    );
  }

  return trends..sort(_compareActivityTrends);
}

int _compareActivityTrends(_ActivityTrend left, _ActivityTrend right) {
  final leftActivity = activityForAction(left.action);
  final rightActivity = activityForAction(right.action);
  final leftSortOrder = leftActivity?.sortOrder;
  final rightSortOrder = rightActivity?.sortOrder;
  if (leftSortOrder != null && rightSortOrder != null) {
    final order = leftSortOrder.compareTo(rightSortOrder);
    if (order != 0) return order;
  } else if (leftSortOrder != null) {
    return -1;
  } else if (rightSortOrder != null) {
    return 1;
  }

  final leftLatest = left.latestLogAt;
  final rightLatest = right.latestLogAt;
  if (leftLatest != null && rightLatest != null) {
    final latestOrder = rightLatest.compareTo(leftLatest);
    if (latestOrder != 0) return latestOrder;
  } else if (leftLatest != null) {
    return -1;
  } else if (rightLatest != null) {
    return 1;
  }

  return left.action.name.compareTo(right.action.name);
}

bool _usesAmountValue(String unit) {
  return switch (unit) {
    '分钟' || '次' || '秒' || '秒保持' || '次/天' || '组' => true,
    _ => false,
  };
}

double _amountForLog(RehabLog log) {
  return _usesAmountValue(log.unit) && log.amountValue > 0
      ? log.amountValue
      : 1;
}

String _unitForLogAmount(RehabLog log) {
  return _usesAmountValue(log.unit) && log.amountValue > 0 ? log.unit : '次';
}

String _actionNameFor(DailyReport report, int actionId) {
  for (final action in report.rehabActions) {
    if (action.id == actionId) {
      return action.name;
    }
  }
  return legacyActionNameForId(actionId) ?? '未知活动';
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

String _formatClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _ActivityTrend {
  const _ActivityTrend({
    required this.action,
    required this.unit,
    required this.totalCount,
    required this.totalAmount,
    required this.latestLogAt,
    required this.days,
  });

  final RehabAction action;
  final String unit;
  final int totalCount;
  final double totalAmount;
  final DateTime? latestLogAt;
  final List<_ActivityTrendDay> days;
}

class _ActivityTrendDay {
  const _ActivityTrendDay({
    required this.day,
    required this.value,
  });

  final DateTime day;
  final double value;
}
