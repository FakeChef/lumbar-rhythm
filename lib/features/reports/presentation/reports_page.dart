import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/domain/action_item.dart';
import '../../posture/domain/posture_summary.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../application/daily_report_controller.dart';
import '../domain/daily_report.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(dailyReportControllerProvider);
    final period = ref.watch(reportPeriodProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '康复报告',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            IconButton(
              tooltip: '刷新报告',
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () => ref.invalidate(dailyReportControllerProvider),
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
          data: (report) => _ReportContent(report: report, period: period),
        ),
        const SizedBox(height: 12),
        const Text(
          '本报告仅用于个人康复记录回顾，不作为医疗诊断或治疗依据。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report, required this.period});

  final DailyReport report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final summary = report.rehabSummary;
    final hasAnyRecord = summary.totalCount > 0 ||
        report.postureSummary.sessions.isNotEmpty ||
        report.dailyNotes.isNotEmpty ||
        report.milestones.any((milestone) => milestone.isCompleted);

    if (!hasAnyRecord) {
      return _EmptyCard(
        title: '${_periodTitle(period)}康复报告',
        message: '当前时间范围内还没有康复日志。你可以在首页记录康复动作、坐站节奏或今日康复小结。',
      );
    }

    if (period == ReportPeriod.day) {
      return _DailyRehabOverview(report: report);
    }

    return _RehabTrendOverview(report: report, period: period);
  }
}

class _DailyRehabOverview extends StatelessWidget {
  const _DailyRehabOverview({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final summary = report.rehabSummary;
    final posture = report.postureSummary;
    final walkingTotal = summary.totalAmountForActionNamed('步行');
    final muchWorseCount = summary.reactionCount(RehabReaction.muchWorse);
    final postSurgeryDay = report.postSurgeryDay(DateTime.now());

    return Column(
      children: [
        _SectionCard(
          title: '今日康复报告',
          subtitle:
              postSurgeryDay == null ? '可在设置中添加手术日期' : '术后第 $postSurgeryDay 天',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SoftMetricRow(
                  label: '有记录天数', value: '${report.recordedDayCount} 天'),
              _SoftMetricRow(
                label: '已完成康复节点',
                value: '${report.completedMilestoneCount} 个',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SittingStandingReportCard(report: report),
        const SizedBox(height: 12),
        _OverviewGrid(
          cards: [
            _OverviewCardData(
              icon: Icons.event_seat_outlined,
              color: _ReportColors.primary,
              title: '坐姿累计',
              value: _formatDuration(posture.sittingTotal),
              subtitle: '最长 ${_formatDuration(posture.longestSitting)}',
            ),
            _OverviewCardData(
              icon: Icons.accessibility_new_outlined,
              color: _ReportColors.walking,
              title: '站立累计',
              value: _formatDuration(posture.standingTotal),
              subtitle: '最长 ${_formatDuration(posture.longestStanding)}',
            ),
            _OverviewCardData(
              icon: Icons.directions_walk_outlined,
              color: _ReportColors.highlight,
              title: '步行总量',
              value: '${_formatNumber(walkingTotal)} 分钟',
              subtitle: '来自康复动作记录',
            ),
            _OverviewCardData(
              icon: Icons.visibility_outlined,
              color: muchWorseCount > 0
                  ? _ReportColors.warning
                  : _ReportColors.primary,
              title: '需观察',
              value: '$muchWorseCount 次',
              subtitle: '明显加重的记录次数',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '今日康复小结',
          subtitle: '腰部、腿部和疲劳评分',
          child: _DailyNotePanel(report: report),
        ),
      ],
    );
  }
}

class _RehabTrendOverview extends StatelessWidget {
  const _RehabTrendOverview({required this.report, required this.period});

  final DailyReport report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final bins = _trendBinsFor(report, period);

    return Column(
      children: [
        _PostureRhythmTrendCard(report: report, period: period),
        const SizedBox(height: 12),
        _TrendCard(
          title: '${_periodTitle(period)}康复动作趋势',
          subtitle: '按天统计康复记录次数',
          bins: bins,
          valueFor: (bin) => bin.rehabCount.toDouble(),
          labelFor: (bin) => '${bin.rehabCount} 次',
          color: _ReportColors.primary,
          emptyMessage: '当前时间范围内还没有康复动作记录。',
        ),
        const SizedBox(height: 12),
        _TrendCard(
          title: '${_periodTitle(period)}步行趋势',
          subtitle: '按天统计步行总量',
          bins: bins,
          valueFor: (bin) => bin.walkingMinutes,
          labelFor: (bin) => '${_formatNumber(bin.walkingMinutes)} 分',
          color: _ReportColors.walking,
          emptyMessage: '当前时间范围内还没有步行记录。',
        ),
        const SizedBox(height: 12),
        _SymptomTrendCard(report: report),
        const SizedBox(height: 12),
        _TrendSummaryCard(report: report),
      ],
    );
  }
}

class _SittingStandingReportCard extends StatelessWidget {
  const _SittingStandingReportCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final posture = report.postureSummary;

    return _SectionCard(
      title: '坐站节奏报告',
      subtitle: '记录显示，仅作为个人观察参考',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SoftMetricRow(
              label: '坐姿累计', value: _formatDuration(posture.sittingTotal)),
          _SoftMetricRow(
              label: '站立累计', value: _formatDuration(posture.standingTotal)),
          _SoftMetricRow(
              label: '走动累计', value: _formatDuration(posture.walkingTotal)),
          _SoftMetricRow(
              label: '休息累计', value: _formatDuration(posture.restingTotal)),
          _SoftMetricRow(
            label: '最长连续坐姿',
            value: _formatDuration(posture.longestSitting),
          ),
          _SoftMetricRow(
            label: '最长连续站立',
            value: _formatDuration(posture.longestStanding),
          ),
          _SoftMetricRow(
            label: '久坐超阈值次数',
            value: '${posture.sittingOverThresholdCount} 次',
          ),
          _SoftMetricRow(
            label: '久站超阈值次数',
            value: '${posture.standingOverThresholdCount} 次',
          ),
          _SoftMetricRow(label: '姿势切换次数', value: '${posture.switchCount} 次'),
        ],
      ),
    );
  }
}

class _PostureRhythmTrendCard extends StatelessWidget {
  const _PostureRhythmTrendCard({
    required this.report,
    required this.period,
  });

  final DailyReport report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final stats = _recentPostureStats(report);
    final bins = _postureTrendBinsFor(report, period);
    final sittingExceeded =
        report.recentPostureSummary.sittingOverThresholdCount;
    final standingExceeded =
        report.recentPostureSummary.standingOverThresholdCount;
    final discomfortAfterTimeout = report.recentRehabLogs.where((log) {
      return log.source == 'posture_reminder' &&
          log.reaction == RehabReaction.muchWorse;
    }).length;

    return _SectionCard(
      title: period == ReportPeriod.week ? '最近 7 天坐站节奏报告' : '本月坐站节奏报告',
      subtitle: '坐站趋势来自姿势记录',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SoftMetricRow(
            label: '平均最长坐姿',
            value: _formatDuration(stats.averageLongestSitting),
          ),
          _SoftMetricRow(
            label: '平均最长站立',
            value: _formatDuration(stats.averageLongestStanding),
          ),
          _SoftMetricRow(
            label: '久坐 / 久站超阈值总次数',
            value: '$sittingExceeded / $standingExceeded 次',
          ),
          _SoftMetricRow(
            label: '超时后明显不适次数',
            value: '$discomfortAfterTimeout 次',
          ),
          const SizedBox(height: 8),
          Text(
            period == ReportPeriod.week
                ? '本周记录显示，你有 $sittingExceeded 次坐姿超过设定提醒时间，可作为下周观察参考。'
                : '本月记录显示，你有 $sittingExceeded 次坐姿超过设定提醒时间，可作为观察参考。',
          ),
          const SizedBox(height: 16),
          _StackedPostureBars(bins: bins),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.cards});

  final List<_OverviewCardData> cards;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        return _OverviewCard(data: cards[index]);
      },
    );
  }
}

class _OverviewCardData {
  const _OverviewCardData({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.data});

  final _OverviewCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Icon(data.icon, color: data.color, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: data.color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
      return const Text('今天还没有康复小结。');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SoftMetricRow(label: '总体感觉', value: note.overallFeeling.label),
        _ScoreBars(
          backPain: note.backPainScore,
          legSymptom: note.legSymptomScore,
          fatigue: note.fatigueScore,
        ),
        if (note.note != null && note.note!.isNotEmpty) Text(note.note!),
      ],
    );
  }
}

class _ScoreBars extends StatelessWidget {
  const _ScoreBars({
    required this.backPain,
    required this.legSymptom,
    required this.fatigue,
  });

  final int backPain;
  final int legSymptom;
  final int fatigue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScoreBar(label: '腰部不适', value: backPain),
        _ScoreBar(label: '腿部症状', value: legSymptom),
        _ScoreBar(label: '疲劳感', value: fatigue),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
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

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.subtitle,
    required this.bins,
    required this.valueFor,
    required this.labelFor,
    required this.color,
    required this.emptyMessage,
  });

  final String title;
  final String subtitle;
  final List<_TrendBin> bins;
  final double Function(_TrendBin bin) valueFor;
  final String Function(_TrendBin bin) labelFor;
  final Color color;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        bins.map(valueFor).fold(0.0, (max, value) => value > max ? value : max);

    return _SectionCard(
      title: title,
      subtitle: subtitle,
      child: maxValue <= 0
          ? Text(emptyMessage)
          : SizedBox(
              height: 210,
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
    final height = _barHeight(value, maxValue);

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

    if (maxMinutes <= 0) {
      return const Text('当前时间范围内还没有坐站节奏记录。');
    }

    return SizedBox(
      height: 190,
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
                      height: 128,
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
    final totalHeight = 18 + 110 * (bin.totalMinutes / maxMinutes);
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

class _TrendSummaryCard extends StatelessWidget {
  const _TrendSummaryCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final summary = report.rehabSummary;
    final posture = report.postureSummary;
    final topAction = summary.mostCompletedAction()?.name ?? '暂无';
    final day = report.postSurgeryDay(DateTime.now());

    return _SectionCard(
      title: '术后阶段报告',
      subtitle: '当前时间范围',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SoftMetricRow(
              label: '术后第几天', value: day == null ? '未设置' : '第 $day 天'),
          _SoftMetricRow(label: '有记录天数', value: '${report.recordedDayCount} 天'),
          _SoftMetricRow(
              label: '坐姿累计', value: _formatDuration(posture.sittingTotal)),
          _SoftMetricRow(
            label: '最长连续坐姿',
            value: _formatDuration(posture.longestSitting),
          ),
          _SoftMetricRow(
              label: '站立累计', value: _formatDuration(posture.standingTotal)),
          _SoftMetricRow(
            label: '最长连续站立',
            value: _formatDuration(posture.longestStanding),
          ),
          _SoftMetricRow(label: '康复记录', value: '${summary.totalCount} 次'),
          _SoftMetricRow(
            label: '步行总量',
            value:
                '${_formatNumber(summary.totalAmountForActionNamed('步行'))} 分钟',
          ),
          _SoftMetricRow(label: '完成最多', value: topAction),
          _SoftMetricRow(
            label: '明显加重',
            value: '${summary.reactionCount(RehabReaction.muchWorse)} 次',
          ),
          _SoftMetricRow(
            label: '已完成康复节点',
            value: '${report.completedMilestoneCount} 个',
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

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
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SoftMetricRow extends StatelessWidget {
  const _SoftMetricRow({required this.label, required this.value});

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
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: '暂无数据',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.self_improvement_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
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
    return _SectionCard(
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

class _TrendBin {
  const _TrendBin({
    required this.day,
    required this.label,
    required this.rehabCount,
    required this.walkingMinutes,
  });

  final DateTime day;
  final String label;
  final int rehabCount;
  final double walkingMinutes;
}

class _PostureTrendBin {
  const _PostureTrendBin({
    required this.day,
    required this.label,
    required this.sittingMinutes,
    required this.standingMinutes,
    required this.walkingMinutes,
    required this.restingMinutes,
  });

  final DateTime day;
  final String label;
  final double sittingMinutes;
  final double standingMinutes;
  final double walkingMinutes;
  final double restingMinutes;

  double get totalMinutes {
    return sittingMinutes + standingMinutes + walkingMinutes + restingMinutes;
  }
}

class _RecentPostureStats {
  const _RecentPostureStats({
    required this.averageLongestSitting,
    required this.averageLongestStanding,
  });

  final Duration averageLongestSitting;
  final Duration averageLongestStanding;
}

class _SymptomTrendCard extends StatelessWidget {
  const _SymptomTrendCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final notes = report.recentDailyNotes;
    return _SectionCard(
      title: '最近 7 天康复小结趋势',
      subtitle: '分数越高代表当天主观感受越强',
      child: notes.isEmpty
          ? const Text('最近 7 天还没有康复小结。')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final note in notes)
                  _SoftMetricRow(
                    label: '${note.date.month}/${note.date.day}',
                    value:
                        '腰 ${note.backPainScore} · 腿 ${note.legSymptomScore} · 疲劳 ${note.fatigueScore}',
                  ),
              ],
            ),
    );
  }
}

abstract final class _ReportColors {
  static const primary = Color(0xFF2F6B5F);
  static const walking = Color(0xFFE09F3E);
  static const highlight = Color(0xFF5B7CFA);
  static const warning = Color(0xFFD96C4A);
  static const resting = Color(0xFF7A6FF0);
}

_RecentPostureStats _recentPostureStats(DailyReport report) {
  final now = report.recentPostureSummary.now;
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));
  final longestSitting = <Duration>[];
  final longestStanding = <Duration>[];

  for (var index = 0; index < 7; index++) {
    final day = start.add(Duration(days: index));
    final summary = _postureSummaryForDay(report.recentPostureSummary, day);
    if (summary.sessions.isNotEmpty) {
      longestSitting.add(summary.longestSitting);
      longestStanding.add(summary.longestStanding);
    }
  }

  return _RecentPostureStats(
    averageLongestSitting: _averageDuration(longestSitting),
    averageLongestStanding: _averageDuration(longestStanding),
  );
}

List<_PostureTrendBin> _postureTrendBinsFor(
  DailyReport report,
  ReportPeriod period,
) {
  final now = report.postureSummary.now;
  final today = DateTime(now.year, now.month, now.day);
  final start = switch (period) {
    ReportPeriod.day => today,
    ReportPeriod.week => today.subtract(const Duration(days: 6)),
    ReportPeriod.month => DateTime(now.year, now.month),
  };
  final length = switch (period) {
    ReportPeriod.day => 1,
    ReportPeriod.week => 7,
    ReportPeriod.month => DateTime(now.year, now.month + 1, 0).day,
  };

  final source = period == ReportPeriod.week
      ? report.recentPostureSummary
      : report.postureSummary;

  return [
    for (var index = 0; index < length; index++)
      _postureTrendBinFor(
        source: source,
        day: start.add(Duration(days: index)),
        period: period,
      ),
  ];
}

_PostureTrendBin _postureTrendBinFor({
  required PostureSummary source,
  required DateTime day,
  required ReportPeriod period,
}) {
  final summary = _postureSummaryForDay(source, day);
  return _PostureTrendBin(
    day: day,
    label: _trendLabel(day, period),
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

Duration _averageDuration(List<Duration> values) {
  if (values.isEmpty) {
    return Duration.zero;
  }
  final seconds = values
          .map((value) => value.inSeconds)
          .fold<int>(0, (sum, value) => sum + value) /
      values.length;
  return Duration(seconds: seconds.round());
}

List<_TrendBin> _trendBinsFor(DailyReport report, ReportPeriod period) {
  final now = report.postureSummary.now;
  final today = DateTime(now.year, now.month, now.day);
  final start = switch (period) {
    ReportPeriod.day => today,
    ReportPeriod.week => today.subtract(const Duration(days: 6)),
    ReportPeriod.month => DateTime(now.year, now.month),
  };
  final length = switch (period) {
    ReportPeriod.day => 1,
    ReportPeriod.week => 7,
    ReportPeriod.month => DateTime(now.year, now.month + 1, 0).day,
  };

  return [
    for (var index = 0; index < length; index++)
      _binFor(
        day: start.add(Duration(days: index)),
        report: report,
        period: period,
      ),
  ];
}

_TrendBin _binFor({
  required DateTime day,
  required DailyReport report,
  required ReportPeriod period,
}) {
  final nextDay = day.add(const Duration(days: 1));
  final logs = report.rehabSummary.logs.where((log) {
    return !log.createdAt.isBefore(day) && log.createdAt.isBefore(nextDay);
  }).toList();
  final summary = RehabSummary(logs: logs, actions: report.rehabActions);

  return _TrendBin(
    day: day,
    label: _trendLabel(day, period),
    rehabCount: logs.length,
    walkingMinutes: summary.totalAmountForActionNamed('步行'),
  );
}

String _trendLabel(DateTime day, ReportPeriod period) {
  if (period == ReportPeriod.month) {
    return '${day.day}';
  }
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

double _barHeight(double value, double maxValue) {
  if (value <= 0 || maxValue <= 0) {
    return 0;
  }
  return 18 + 120 * (value / maxValue);
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
