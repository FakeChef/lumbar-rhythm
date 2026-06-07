import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/gallery_image_saver.dart';
import '../../actions/domain/action_item.dart';
import '../../posture/domain/posture_summary.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../application/daily_report_controller.dart';
import '../domain/daily_report.dart';

const reportDisclaimerText = '本报告仅用于个人记录回顾，不作为医疗依据。';

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
                    '回顾你的坐站节奏和康复记录',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        reportState.when(
          loading: () => const _ReportLoading(),
          error: (error, stackTrace) => _ReportError(
            onRetry: () => ref.invalidate(dailyReportControllerProvider),
          ),
          data: (report) => _ReportContent(
            boundaryKey: _reportBoundaryKey,
            report: report,
            period: period,
            onSaveToGallery: _saveReportToGallery,
          ),
        ),
      ],
    );
  }

  Future<void> _saveReportToGallery() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _captureReportPng();
      final result = await ref.read(galleryImageSaverProvider).savePng(
            bytes: bytes,
            fileName: 'lumbar-rhythm-report-${DateTime.now().millisecondsSinceEpoch}.png',
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.saved ? '已保存到相册：Pictures/Lumbar Rhythm' : '保存失败，请稍后重试。',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('保存失败，请稍后重试。')),
      );
    }
  }

  Future<Uint8List> _captureReportPng() async {
    final boundary = _reportBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Report content is not ready.');
    }
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode report image.');
    }
    return byteData.buffer.asUint8List();
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.boundaryKey,
    required this.report,
    required this.period,
    required this.onSaveToGallery,
  });

  final GlobalKey boundaryKey;
  final DailyReport report;
  final ReportPeriod period;
  final VoidCallback onSaveToGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                _TodayReportSection(report: report),
                const SizedBox(height: 12),
                _SittingStandingReportSection(report: report),
                const SizedBox(height: 12),
                _RecentTrendSection(report: report),
                const SizedBox(height: 12),
                _RehabActionReportSection(report: report, period: period),
                const SizedBox(height: 12),
                const _ShortDisclaimerText(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SaveReportSection(onSaveToGallery: onSaveToGallery),
      ],
    );
  }
}

class _TodayReportSection extends StatelessWidget {
  const _TodayReportSection({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final postSurgeryDay = report.postSurgeryDay(DateTime.now());
    final summary = report.rehabSummary;
    final posture = report.postureSummary;

    return _ReportSection(
      icon: Icons.today_outlined,
      title: '今日康复报告',
      subtitle: postSurgeryDay == null
          ? '可在设置中补充手术日期，也可以继续跳过'
          : '术后第 $postSurgeryDay 天',
      child: Column(
        children: [
          _MetricRow(label: '今日康复记录', value: '${summary.totalCount} 次'),
          _MetricRow(
            label: '今日坐姿累计',
            value: _formatDuration(posture.sittingTotal),
          ),
          _MetricRow(
            label: '今日站立累计',
            value: _formatDuration(posture.standingTotal),
          ),
          _MetricRow(
            label: '今日走动累计',
            value: _formatDuration(posture.walkingTotal),
          ),
          _MetricRow(
            label: '已完成康复节点',
            value: '${report.completedMilestoneCount} 个',
          ),
          const SizedBox(height: 8),
          _DailyNotePanel(report: report),
        ],
      ),
    );
  }
}

class _SittingStandingReportSection extends StatelessWidget {
  const _SittingStandingReportSection({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final posture = report.postureSummary;

    return _ReportSection(
      icon: Icons.swap_vert_circle_outlined,
      title: '坐站节奏报告',
      subtitle: '查看坐、站、走动和休息的本地记录',
      child: Column(
        children: [
          _MetricRow(
              label: '坐姿累计', value: _formatDuration(posture.sittingTotal)),
          _MetricRow(
            label: '站立累计',
            value: _formatDuration(posture.standingTotal),
          ),
          _MetricRow(
              label: '走动累计', value: _formatDuration(posture.walkingTotal)),
          _MetricRow(
              label: '休息累计', value: _formatDuration(posture.restingTotal)),
          _MetricRow(
            label: '最长连续坐姿',
            value: _formatDuration(posture.longestSitting),
          ),
          _MetricRow(
            label: '最长连续站立',
            value: _formatDuration(posture.longestStanding),
          ),
          _MetricRow(
            label: '久坐超过提醒间隔',
            value: '${posture.sittingOverThresholdCount} 次',
          ),
          _MetricRow(
            label: '久站超过提醒间隔',
            value: '${posture.standingOverThresholdCount} 次',
          ),
          _MetricRow(label: '姿势切换次数', value: '${posture.switchCount} 次'),
        ],
      ),
    );
  }
}

class _RecentTrendSection extends StatelessWidget {
  const _RecentTrendSection({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final postureBins = _postureTrendBinsFor(report);
    final rehabBins = _rehabTrendBinsFor(report);
    final postureHasData = postureBins.any((bin) => bin.totalMinutes > 0);
    final rehabHasData = rehabBins.any((bin) => bin.rehabCount > 0);

    return _ReportSection(
      icon: Icons.trending_up_outlined,
      title: '最近 7 天趋势',
      subtitle: '按天回顾坐站节奏、走动和康复动作记录',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (postureHasData) _StackedPostureBars(bins: postureBins),
          if (!postureHasData) const _EmptyHint(text: '最近 7 天还没有坐站节奏记录。'),
          const SizedBox(height: 16),
          if (rehabHasData)
            _TrendBars(
              bins: rehabBins,
              valueFor: (bin) => bin.rehabCount.toDouble(),
              labelFor: (bin) => '${bin.rehabCount} 次',
              color: _ReportColors.primary,
            ),
          if (!rehabHasData) const _EmptyHint(text: '最近 7 天还没有康复动作记录。'),
          const SizedBox(height: 12),
          _RecentNotesPanel(report: report),
        ],
      ),
    );
  }
}

class _RehabActionReportSection extends StatelessWidget {
  const _RehabActionReportSection({
    required this.report,
    required this.period,
  });

  final DailyReport report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final summary = report.rehabSummary;
    final topAction = summary.mostCompletedAction()?.name ?? '暂无';
    final walkingTotal = summary.totalAmountForActionNamed('步行');
    final muchWorseCount = summary.reactionCount(RehabReaction.muchWorse);

    return _ReportSection(
      icon: Icons.self_improvement_outlined,
      title: '康复动作报告',
      subtitle: '${_periodTitle(period)}范围内的动作记录汇总',
      child: Column(
        children: [
          _MetricRow(label: '动作记录总数', value: '${summary.totalCount} 次'),
          _MetricRow(label: '步行总量', value: '${_formatNumber(walkingTotal)} 分钟'),
          _MetricRow(label: '记录最多的动作', value: topAction),
          _MetricRow(label: '明显加重记录', value: '$muchWorseCount 次'),
          _MetricRow(
              label: '需要继续观察的动作', value: summary.observationActionNames()),
        ],
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
      title: '保存报告到相册',
      subtitle: '保存为本地 PNG 图片，不上传数据',
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: onSaveToGallery,
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text('保存报告到相册'),
        ),
      ),
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

class _DailyNotePanel extends StatelessWidget {
  const _DailyNotePanel({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final note = report.dailyNotes.isEmpty ? null : report.dailyNotes.last;
    if (note == null) {
      return const _EmptyHint(text: '今天还没有康复小结。');
    }

    return Column(
      children: [
        _MetricRow(label: '总体感觉', value: note.overallFeeling.label),
        _ScoreRow(label: '腰部不适', value: note.backPainScore),
        _ScoreRow(label: '腿部症状', value: note.legSymptomScore),
        _ScoreRow(label: '疲劳感', value: note.fatigueScore),
        if (note.note != null && note.note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(note.note!),
            ),
          ),
      ],
    );
  }
}

class _RecentNotesPanel extends StatelessWidget {
  const _RecentNotesPanel({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final notes = report.recentDailyNotes;
    if (notes.isEmpty) {
      return const _EmptyHint(text: '最近 7 天还没有康复小结。');
    }

    return Column(
      children: [
        for (final note in notes)
          _MetricRow(
            label: '${note.date.month}/${note.date.day}',
            value:
                '腰 ${note.backPainScore} / 腿 ${note.legSymptomScore} / 疲劳 ${note.fatigueScore}',
          ),
      ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
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

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 76, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(
              value: value / 10,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value/10'),
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

class _TrendBars extends StatelessWidget {
  const _TrendBars({
    required this.bins,
    required this.valueFor,
    required this.labelFor,
    required this.color,
  });

  final List<_TrendBin> bins;
  final double Function(_TrendBin bin) valueFor;
  final String Function(_TrendBin bin) labelFor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        bins.map(valueFor).fold(0.0, (max, value) => value > max ? value : max);

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bin in bins)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      labelFor(bin),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    _TrendBar(
                      value: valueFor(bin),
                      maxValue: maxValue,
                      color: color,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bin.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final double value;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = _barHeight(value, maxValue, maxHeight: 92);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: value <= 0
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(width: 18, height: height <= 0 ? 2 : height),
    );
  }
}

class _StackedPostureBars extends StatelessWidget {
  const _StackedPostureBars({required this.bins});

  final List<_PostureTrendBin> bins;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = bins.fold<double>(0, (max, bin) {
      final value = bin.totalMinutes;
      return value > max ? value : max;
    });

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bin in bins)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 120,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _PostureStackBar(
                          bin: bin,
                          maxMinutes: maxMinutes,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bin.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostureStackBar extends StatelessWidget {
  const _PostureStackBar({required this.bin, required this.maxMinutes});

  final _PostureTrendBin bin;
  final double maxMinutes;

  @override
  Widget build(BuildContext context) {
    final totalHeight = _barHeight(
      bin.totalMinutes,
      maxMinutes,
      minHeight: 18,
      maxHeight: 112,
    );
    final segments = [
      (value: bin.sittingMinutes, color: _ReportColors.primary),
      (value: bin.standingMinutes, color: _ReportColors.walking),
      (value: bin.walkingMinutes, color: _ReportColors.highlight),
      (value: bin.restingMinutes, color: _ReportColors.resting),
    ].where((segment) => segment.value > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 18,
        height: totalHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final segment in segments)
              Expanded(
                flex: (segment.value * 100).round().clamp(1, 100000),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: segment.color),
                  child: const SizedBox(width: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendBin {
  const _TrendBin({
    required this.label,
    required this.rehabCount,
  });

  final String label;
  final int rehabCount;
}

class _PostureTrendBin {
  const _PostureTrendBin({
    required this.label,
    required this.sittingMinutes,
    required this.standingMinutes,
    required this.walkingMinutes,
    required this.restingMinutes,
  });

  final String label;
  final double sittingMinutes;
  final double standingMinutes;
  final double walkingMinutes;
  final double restingMinutes;

  double get totalMinutes {
    return sittingMinutes + standingMinutes + walkingMinutes + restingMinutes;
  }
}

abstract final class _ReportColors {
  static const primary = Color(0xFF2F6B5F);
  static const walking = Color(0xFFE09F3E);
  static const highlight = Color(0xFF5B7CFA);
  static const resting = Color(0xFF7A6FF0);
}

List<_PostureTrendBin> _postureTrendBinsFor(DailyReport report) {
  final now = report.recentPostureSummary.now;
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));

  return [
    for (var index = 0; index < 7; index++)
      _postureTrendBinFor(
        source: report.recentPostureSummary,
        day: start.add(Duration(days: index)),
      ),
  ];
}

_PostureTrendBin _postureTrendBinFor({
  required PostureSummary source,
  required DateTime day,
}) {
  final summary = _postureSummaryForDay(source, day);
  return _PostureTrendBin(
    label: _trendLabel(day),
    sittingMinutes: summary.sittingTotal.inMinutes.toDouble(),
    standingMinutes: summary.standingTotal.inMinutes.toDouble(),
    walkingMinutes: summary.walkingTotal.inMinutes.toDouble(),
    restingMinutes: summary.restingTotal.inMinutes.toDouble(),
  );
}

PostureSummary _postureSummaryForDay(PostureSummary source, DateTime day) {
  final nextDay = day.add(const Duration(days: 1));
  final sessions = source.sessions.where((session) {
    return !session.startedAt.isBefore(day) &&
        session.startedAt.isBefore(nextDay);
  }).toList();

  return PostureSummary(
    sessions: sessions,
    now: nextDay,
    sittingThreshold: source.sittingThreshold,
    standingThreshold: source.standingThreshold,
  );
}

List<_TrendBin> _rehabTrendBinsFor(DailyReport report) {
  final now = report.recentPostureSummary.now;
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));

  return [
    for (var index = 0; index < 7; index++)
      _rehabTrendBinFor(
        day: start.add(Duration(days: index)),
        report: report,
      ),
  ];
}

_TrendBin _rehabTrendBinFor({
  required DateTime day,
  required DailyReport report,
}) {
  final nextDay = day.add(const Duration(days: 1));
  final logs = report.recentRehabLogs.where((log) {
    return !log.createdAt.isBefore(day) && log.createdAt.isBefore(nextDay);
  }).toList();

  return _TrendBin(
    label: _trendLabel(day),
    rehabCount: logs.length,
  );
}

String _trendLabel(DateTime day) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return labels[day.weekday - 1];
}

String _periodTitle(ReportPeriod period) {
  return switch (period) {
    ReportPeriod.day => '今日',
    ReportPeriod.week => '本周',
    ReportPeriod.month => '本月',
  };
}

double _barHeight(
  double value,
  double maxValue, {
  double minHeight = 2,
  double maxHeight = 120,
}) {
  if (value <= 0 || maxValue <= 0) {
    return 0;
  }
  return minHeight + (maxHeight - minHeight) * (value / maxValue);
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) {
    return '$hours 小时 $minutes 分钟';
  }
  if (hours > 0) {
    return '$hours 小时';
  }
  return '$minutes 分钟';
}
