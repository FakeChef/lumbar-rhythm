import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/gallery_image_saver.dart';
import '../../actions/domain/action_item.dart';
import '../application/daily_report_controller.dart';
import '../domain/daily_report.dart';
import 'follow_up_report_image.dart';

const reportDisclaimerText = '本报告仅用于个人康复记录回顾，不作为专业判断依据。';

typedef FollowUpReportPngCapture = Future<Uint8List> Function(
  BuildContext context,
  DailyReport report,
  ReportPeriod period,
);

final followUpReportPngCaptureProvider = Provider<FollowUpReportPngCapture>(
  (ref) => captureFollowUpReportPng,
);

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(dailyReportControllerProvider);
    final period = ref.watch(reportPeriodProvider);

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
            onSaveToGallery: () => _saveReportToGallery(report, period),
          ),
        ),
      ],
    );
  }

  Future<void> _saveReportToGallery(
    DailyReport report,
    ReportPeriod period,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(followUpReportPngCaptureProvider)(
          context, report, period);
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

Future<Uint8List> captureFollowUpReportPng(
  BuildContext context,
  DailyReport report,
  ReportPeriod period,
) async {
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context);
  final generatedAt = DateTime.now();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return Positioned.fill(
        child: Material(
          color: Colors.white,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: boundaryKey,
              child: FollowUpReportImage(
                report: report,
                generatedAt: generatedAt,
                rangeLabel: _periodTitle(period),
                useCurrentRange: true,
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Follow-up report image is not ready.');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode follow-up report image.');
    }
    return byteData.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.report,
    required this.period,
    required this.onSaveToGallery,
  });

  final DailyReport report;
  final ReportPeriod period;
  final VoidCallback onSaveToGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              if (period == ReportPeriod.day) ...[
                _DailyRehabLogSection(report: report),
                const SizedBox(height: 20),
              ] else ...[
                _RehabRangeSummarySection(report: report, period: period),
                const SizedBox(height: 20),
                _RehabLogTrendSection(
                  report: report,
                  days: period == ReportPeriod.week ? 7 : 30,
                ),
                const SizedBox(height: 20),
              ],
              const _ShortDisclaimerText(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SaveReportSection(onSaveToGallery: onSaveToGallery),
      ],
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

class _RehabRangeSummarySection extends StatelessWidget {
  const _RehabRangeSummarySection({
    required this.report,
    required this.period,
  });

  final DailyReport report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final days = period == ReportPeriod.week ? 7 : 30;
    final title = period == ReportPeriod.week ? '最近 7 天康复汇总' : '最近 30 天康复汇总';
    final summary = report.rehabSummary;
    final hasData = report.rehabLogs.isNotEmpty;

    if (!hasData) {
      return KeyedSubtree(
        key: ValueKey(period == ReportPeriod.week
            ? 'rehab-report-week-section'
            : 'rehab-report-month-section'),
        child: _ReportSection(
          icon: Icons.summarize_outlined,
          title: title,
          subtitle: '本地康复动作记录汇总',
          child: _EmptyHint(text: '$title 还没有足够记录。'),
        ),
      );
    }

    return KeyedSubtree(
      key: ValueKey(period == ReportPeriod.week
          ? 'rehab-report-week-section'
          : 'rehab-report-month-section'),
      child: _ReportSection(
        icon: Icons.summarize_outlined,
        title: title,
        subtitle: '按最近 $days 天回顾康复动作记录',
        child: Column(
          children: [
            _MetricRow(
                label: '记录天数', value: '${_rehabRecordedDayCount(report)} 天'),
            _MetricRow(label: '康复记录总次数', value: '${summary.totalCount} 次'),
            _MetricRow(
              label: '步行/有氧总分钟数',
              value:
                  '${_formatNumber(_aerobicMinutes(report.rehabLogs, report.rehabActions))} 分钟',
            ),
            _MetricRow(
                label: '记录最多的动作',
                value: summary.mostCompletedAction()?.name ?? '暂无'),
          ],
        ),
      ),
    );
  }
}

class _SaveReportSection extends StatelessWidget {
  const _SaveReportSection({required this.onSaveToGallery});

  final VoidCallback onSaveToGallery;

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      icon: Icons.photo_library_outlined,
      title: '保存当前报告到相册',
      subtitle: '保存为本地 PNG 图片，不上传数据',
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: onSaveToGallery,
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text('保存当前报告到相册'),
        ),
      ),
    );
  }
}

class _RehabLogTrendSection extends StatelessWidget {
  const _RehabLogTrendSection({
    required this.report,
    required this.days,
  });

  final DailyReport report;
  final int days;

  @override
  Widget build(BuildContext context) {
    final summaries = _rehabDaySummaries(report, days);
    final maxValue = summaries
        .map((day) => day.count + day.aerobicMinutes.round())
        .fold<int>(0, (max, value) => value > max ? value : max);

    return _ReportSection(
      icon: Icons.bar_chart_outlined,
      title: days == 7 ? '最近 7 天康复柱状图' : '最近 30 天康复柱状图',
      subtitle: '按天查看康复记录次数和步行/有氧分钟数',
      child: KeyedSubtree(
        key: const ValueKey('report-posture-trend-chart'),
        child: SizedBox(
          key: ValueKey(days == 7
              ? 'rehab-report-week-chart'
              : 'rehab-report-month-chart'),
          height: 168,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in summaries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _RehabTrendBar(
                      day: day,
                      maxValue: maxValue,
                      showLabel: days == 7 || day.day.day == 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RehabTrendBar extends StatelessWidget {
  const _RehabTrendBar({
    required this.day,
    required this.maxValue,
    required this.showLabel,
  });

  final _RehabDaySummary day;
  final int maxValue;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final countFlex = day.count;
    final aerobicFlex = day.aerobicMinutes.round();
    final total = countFlex + aerobicFlex;
    final heightFactor =
        maxValue == 0 ? 0.04 : (total / maxValue).clamp(0.04, 1.0).toDouble();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Column(
                  children: [
                    if (aerobicFlex > 0)
                      Expanded(
                        flex: aerobicFlex,
                        child: ColoredBox(color: scheme.tertiary),
                      ),
                    if (countFlex > 0)
                      Expanded(
                        flex: countFlex,
                        child: ColoredBox(color: scheme.primary),
                      ),
                    if (total == 0)
                      Expanded(
                        child: ColoredBox(
                          color: scheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Text(
            showLabel ? '${day.day.month}/${day.day.day}' : '',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
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

String _periodTitle(ReportPeriod period) {
  return switch (period) {
    ReportPeriod.day => '今日',
    ReportPeriod.week => '最近 7 天',
    ReportPeriod.month => '最近 30 天',
  };
}

int _rehabRecordedDayCount(DailyReport report) {
  return {
    for (final log in report.rehabLogs)
      DateTime(log.createdAt.year, log.createdAt.month, log.createdAt.day),
  }.length;
}

List<_RehabDaySummary> _rehabDaySummaries(DailyReport report, int days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: days - 1));
  return [
    for (var index = 0; index < days; index++)
      _rehabSummaryForDay(
        report,
        start.add(Duration(days: index)),
      ),
  ];
}

_RehabDaySummary _rehabSummaryForDay(DailyReport report, DateTime day) {
  final nextDay = day.add(const Duration(days: 1));
  final logs = report.rehabLogs.where((log) {
    return !log.createdAt.isBefore(day) && log.createdAt.isBefore(nextDay);
  }).toList();
  return _RehabDaySummary(
    day: day,
    count: logs.length,
    aerobicMinutes: _aerobicMinutes(logs, report.rehabActions),
  );
}

double _aerobicMinutes(List<RehabLog> logs, List<RehabAction> actions) {
  final actionsById = {
    for (final action in actions) action.id: action,
  };
  return logs.where((log) {
    final action = actionsById[log.actionId];
    final category = action?.category;
    return category == 'WALK' || category == 'AEROBIC';
  }).fold(0.0, (sum, log) {
    return log.unit == '分钟' ? sum + log.amountValue : sum;
  });
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

class _RehabDaySummary {
  const _RehabDaySummary({
    required this.day,
    required this.count,
    required this.aerobicMinutes,
  });

  final DateTime day;
  final int count;
  final double aerobicMinutes;
}
