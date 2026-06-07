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
import 'follow_up_report_image.dart';

const reportDisclaimerText = '本报告仅用于个人记录回顾，不作为医疗依据。';

typedef FollowUpReportPngCapture = Future<Uint8List> Function(
  BuildContext context,
  DailyReport report,
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
                    '回顾你的坐姿节奏和康复记录',
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
            onSaveToGallery: () => _saveReportToGallery(report),
          ),
        ),
      ],
    );
  }

  Future<void> _saveReportToGallery(DailyReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes =
          await ref.read(followUpReportPngCaptureProvider)(context, report);
      final result = await ref.read(galleryImageSaverProvider).savePng(
            bytes: bytes,
            fileName:
                'lumbar-rhythm-follow-up-${DateTime.now().millisecondsSinceEpoch}.png',
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.saved
                ? '已保存复诊报告到相册：Pictures/Lumbar Rhythm'
                : '保存复诊报告失败，请稍后重试。',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('保存复诊报告失败，请稍后重试。')),
      );
    }
  }

}

Future<Uint8List> captureFollowUpReportPng(
  BuildContext context,
  DailyReport report,
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
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
                _TodayReportSection(report: report),
                const SizedBox(height: 20),
                _SittingReportSection(report: report),
                const SizedBox(height: 20),
                _RehabActionReportSection(report: report, period: period),
                const SizedBox(height: 20),
              ] else ...[
                _RangeSummarySection(report: report, period: period),
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
            label: '久坐超时次数',
            value: '${posture.sittingOverThresholdCount} 次',
          ),
          const SizedBox(height: 8),
          _DailyNotePanel(report: report),
        ],
      ),
    );
  }
}

class _RangeSummarySection extends StatelessWidget {
  const _RangeSummarySection({
    required this.report,
    required this.period,
  });

  final DailyReport report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final days = period == ReportPeriod.week ? 7 : 30;
    final title = period == ReportPeriod.week ? '最近 7 天汇总' : '最近 30 天汇总';
    final summary = report.rehabSummary;
    final posture = report.postureSummary;
    final hasData = report.rehabLogs.isNotEmpty ||
        report.dailyNotes.isNotEmpty ||
        posture.sessions.isNotEmpty;

    if (!hasData) {
      return _ReportSection(
        icon: Icons.summarize_outlined,
        title: title,
        subtitle: '本地记录汇总',
        child: _EmptyHint(text: '$title 还没有足够记录。'),
      );
    }

    return _ReportSection(
      icon: Icons.summarize_outlined,
      title: title,
      subtitle: '按最近 $days 天回顾坐姿节奏和康复记录',
      child: Column(
        children: [
          _MetricRow(label: '记录天数', value: '${_recordedDayCount(report)} 天'),
          if (period == ReportPeriod.week)
            _MetricRow(
              label: '平均最长坐姿',
              value: _formatDuration(_averageLongestSitting(report, days)),
            ),
          _MetricRow(
            label: '久坐超时总次数',
            value: '${posture.sittingOverThresholdCount} 次',
          ),
          if (period == ReportPeriod.week)
            _MetricRow(
              label: '久坐中断总次数',
              value: '${posture.sittingBreakCount} 次',
            ),
          _MetricRow(label: '康复记录总次数', value: '${summary.totalCount} 次'),
          _MetricRow(
            label: '明显加重次数',
            value: '${summary.reactionCount(RehabReaction.muchWorse)} 次',
          ),
          _MetricRow(label: '常见症状标签', value: _commonSymptomTags(report)),
          _MetricRow(label: '简短趋势说明', value: _trendText(report)),
        ],
      ),
    );
  }
}

class _SittingReportSection extends StatelessWidget {
  const _SittingReportSection({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final posture = report.postureSummary;

    return _ReportSection(
      icon: Icons.swap_vert_circle_outlined,
      title: '今日坐姿状态',
      subtitle: '查看今天的坐姿时长和久坐中断',
      child: Column(
        children: [
          _MetricRow(
            label: '今日坐姿累计',
            value: _formatDuration(posture.sittingTotal),
          ),
          _MetricRow(
            label: '久坐超过提醒间隔',
            value: '${posture.sittingOverThresholdCount} 次',
          ),
          _MetricRow(label: '久坐中断次数', value: '${posture.sittingBreakCount} 次'),
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
    final walkingTotal = summary.totalAmountForActionNamed('平地步行');

    return _ReportSection(
      icon: Icons.self_improvement_outlined,
      title: '康复动作报告',
      subtitle: '${_periodTitle(period)}范围内的动作记录汇总',
      child: Column(
        children: [
          _MetricRow(label: '动作记录总数', value: '${summary.totalCount} 次'),
          _MetricRow(label: '步行总量', value: '${_formatNumber(walkingTotal)} 分钟'),
          _MetricRow(label: '记录最多的动作', value: topAction),
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
      title: '保存复诊报告到相册',
      subtitle: '保存为本地 PNG 图片，不上传数据',
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: onSaveToGallery,
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text('保存复诊报告到相册'),
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

String _periodTitle(ReportPeriod period) {
  return switch (period) {
    ReportPeriod.day => '今日',
    ReportPeriod.week => '最近 7 天',
    ReportPeriod.month => '最近 30 天',
  };
}

int _recordedDayCount(DailyReport report) {
  return {
    for (final log in report.rehabLogs)
      DateTime(log.createdAt.year, log.createdAt.month, log.createdAt.day),
    for (final note in report.dailyNotes)
      DateTime(note.date.year, note.date.month, note.date.day),
    for (final session in report.postureSummary.sessions)
      DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      ),
  }.length;
}

Duration _averageLongestSitting(DailyReport report, int days) {
  final now = report.postureSummary.now;
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: days - 1));
  var totalMinutes = 0;
  var activeDays = 0;
  for (var index = 0; index < days; index++) {
    final summary = _postureSummaryForDay(
      report.postureSummary,
      start.add(Duration(days: index)),
    );
    if (summary.sessions.isNotEmpty) {
      activeDays++;
      totalMinutes += summary.longestSitting.inMinutes;
    }
  }
  if (activeDays == 0) {
    return Duration.zero;
  }
  return Duration(minutes: (totalMinutes / activeDays).round());
}

String _commonSymptomTags(DailyReport report) {
  final counts = <String, int>{};
  for (final log in report.rehabLogs) {
    for (final tag in log.symptomTags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) {
    return '暂无';
  }
  final entries = counts.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  return entries.take(3).map((entry) => entry.key).join('、');
}

String _trendText(DailyReport report) {
  if (report.rehabLogs.isEmpty && report.postureSummary.sessions.isEmpty) {
    return '记录还不多，先保持稳定记录。';
  }
  final worseCount =
      report.rehabSummary.reactionCount(RehabReaction.muchWorse);
  if (worseCount > 0) {
    return '有明显加重记录，后续可留意活动量和坐姿时长。';
  }
  if (report.rehabSummary.totalCount > 0 &&
      report.postureSummary.sittingBreakCount > 0) {
    return '近期有康复记录，也有久坐中断记录。';
  }
  return '近期已有本地记录，可继续按自己的节奏补充。';
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
