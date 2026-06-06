import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/domain/action_item.dart';
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
          '报告只汇总康复动作记录，不提供诊断、治疗建议或复发判断。',
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

    if (summary.totalCount == 0) {
      return _EmptyCard(
        title: '${_periodTitle(period)}康复记录',
        message: '当前时间范围内还没有康复动作记录。你可以在首页保存一次康复记录后再回来查看。',
      );
    }

    if (period == ReportPeriod.day) {
      return _DailyRehabOverview(summary: summary);
    }

    return _RehabTrendOverview(report: report, period: period);
  }
}

class _DailyRehabOverview extends StatelessWidget {
  const _DailyRehabOverview({required this.summary});

  final RehabSummary summary;

  @override
  Widget build(BuildContext context) {
    final walkingTotal = summary.totalAmountForActionNamed('步行');
    final muchWorseCount = summary.reactionCount(RehabReaction.muchWorse);
    final topAction = summary.mostCompletedAction()?.name ?? '暂无';
    final observationActions = summary.observationActionNames();

    return Column(
      children: [
        _OverviewGrid(
          cards: [
            _OverviewCardData(
              icon: Icons.fact_check_outlined,
              color: _ReportColors.primary,
              title: '记录次数',
              value: '${summary.totalCount} 次',
              subtitle: '今日保存的康复动作记录',
            ),
            _OverviewCardData(
              icon: Icons.directions_walk_outlined,
              color: _ReportColors.walking,
              title: '步行总量',
              value: '${_formatNumber(walkingTotal)} 分钟',
              subtitle: '来自“步行”动作记录',
            ),
            _OverviewCardData(
              icon: Icons.star_outline,
              color: _ReportColors.highlight,
              title: '完成最多',
              value: topAction,
              subtitle: '按记录次数统计',
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
          title: '做后反应',
          subtitle: '只用于回顾个人记录',
          child: _ObservationPanel(
            muchWorseCount: muchWorseCount,
            observationActions: observationActions,
          ),
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
        _TrendCard(
          title: '${_periodTitle(period)}记录趋势',
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
        _TrendSummaryCard(report: report),
      ],
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

class _ObservationPanel extends StatelessWidget {
  const _ObservationPanel({
    required this.muchWorseCount,
    required this.observationActions,
  });

  final int muchWorseCount;
  final String observationActions;

  @override
  Widget build(BuildContext context) {
    final hasObservation = muchWorseCount > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          hasObservation
              ? Icons.visibility_outlined
              : Icons.check_circle_outline,
          color: hasObservation ? _ReportColors.warning : _ReportColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('明显加重 $muchWorseCount 次'),
              const SizedBox(height: 6),
              Text('需观察动作：$observationActions'),
            ],
          ),
        ),
      ],
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

class _TrendSummaryCard extends StatelessWidget {
  const _TrendSummaryCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final summary = report.rehabSummary;
    final topAction = summary.mostCompletedAction()?.name ?? '暂无';

    return _SectionCard(
      title: '汇总',
      subtitle: '当前时间范围',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

abstract final class _ReportColors {
  static const primary = Color(0xFF2F6B5F);
  static const walking = Color(0xFFE09F3E);
  static const highlight = Color(0xFF5B7CFA);
  static const warning = Color(0xFFD96C4A);
}

List<_TrendBin> _trendBinsFor(DailyReport report, ReportPeriod period) {
  final now = report.postureSummary.now;
  final today = DateTime(now.year, now.month, now.day);
  final start = switch (period) {
    ReportPeriod.day => today,
    ReportPeriod.week => today.subtract(Duration(days: today.weekday - 1)),
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
