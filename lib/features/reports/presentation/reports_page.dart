import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/domain/action_item.dart';
import '../../posture/domain/posture_summary.dart';
import '../../posture/domain/posture_session.dart';
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
              onPressed: () => ref.invalidate(dailyReportControllerProvider),
            ),
          ],
        ),
        const SizedBox(height: 16),
        reportState.when(
          loading: () => const _ReportLoading(),
          error: (error, stackTrace) => _ReportError(
            onRetry: () => ref.invalidate(dailyReportControllerProvider),
          ),
          data: (report) => _ReportContent(report: report),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('报告边界'),
            subtitle: Text('报告只描述个人本地记录，不提供诊断、治疗建议或复发判断。'),
          ),
        ),
      ],
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TodayPostureCard(summary: report.postureSummary),
        const SizedBox(height: 12),
        _TodayRehabCard(summary: report.rehabSummary),
        const SizedBox(height: 12),
        _WeeklyPostureCard(summary: report.recentPostureSummary),
        const SizedBox(height: 12),
        _WeeklyRehabCard(summary: report.recentRehabSummary),
      ],
    );
  }
}

class _TodayPostureCard extends StatelessWidget {
  const _TodayPostureCard({required this.summary});

  final PostureSummary summary;

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      icon: Icons.timer_outlined,
      title: '今日坐站节奏',
      rows: [
        ('累计坐姿时长', _formatDuration(summary.sittingTotal)),
        ('累计站立时长', _formatDuration(summary.standingTotal)),
        ('累计走动时长', _formatDuration(summary.walkingTotal)),
        ('累计休息时长', _formatDuration(summary.restingTotal)),
        ('最长连续坐姿', _formatDuration(summary.longestSitting)),
        ('最长连续站立', _formatDuration(summary.longestStanding)),
        ('姿势切换次数', '${summary.switchCount} 次'),
      ],
      footer: '仅展示个人记录，不代表医学判断。',
    );
  }
}

class _TodayRehabCard extends StatelessWidget {
  const _TodayRehabCard({required this.summary});

  final RehabSummary summary;

  @override
  Widget build(BuildContext context) {
    final topAction = summary.mostCompletedAction();
    final walkingTotal = summary.totalAmountForActionNamed('步行');
    final walkingDisplay = walkingTotal % 1 == 0
        ? walkingTotal.toInt().toString()
        : '$walkingTotal';

    return _MetricCard(
      icon: Icons.accessibility_new_outlined,
      title: '今日康复记录',
      rows: [
        ('今日康复记录次数', '${summary.totalCount} 次'),
        ('今日步行总量', '$walkingDisplay 分钟'),
        ('做后明显加重次数', '${summary.reactionCount(RehabReaction.muchWorse)} 次'),
        ('完成最多动作', topAction?.name ?? '暂无'),
      ],
      footer: '康复记录只用于回顾完成量和做后反应。',
    );
  }
}

class _WeeklyPostureCard extends StatelessWidget {
  const _WeeklyPostureCard({required this.summary});

  final PostureSummary summary;

  @override
  Widget build(BuildContext context) {
    final days = summary.recentDaySummaries(days: 7);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardTitle(
              icon: Icons.stacked_bar_chart_outlined,
              title: '本周坐站趋势',
            ),
            const SizedBox(height: 12),
            for (final day in days) ...[
              Text('${day.day.month}/${day.day.day}'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PostureChip(
                      type: PostureType.sitting, duration: day.sitting),
                  _PostureChip(
                    type: PostureType.standing,
                    duration: day.standing,
                  ),
                  _PostureChip(
                      type: PostureType.walking, duration: day.walking),
                  _PostureChip(
                      type: PostureType.resting, duration: day.resting),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const Text(
              '周报只汇总本地姿势记录。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyRehabCard extends StatelessWidget {
  const _WeeklyRehabCard({required this.summary});

  final RehabSummary summary;

  @override
  Widget build(BuildContext context) {
    final topAction = summary.mostCompletedAction();

    return _MetricCard(
      icon: Icons.fact_check_outlined,
      title: '本周康复摘要',
      rows: [
        ('康复记录次数', '${summary.totalCount} 次'),
        (
          '步行总量',
          '${_formatNumber(summary.totalAmountForActionNamed('步行'))} 分钟'
        ),
        ('明显加重次数', '${summary.reactionCount(RehabReaction.muchWorse)} 次'),
        ('完成最多动作', topAction?.name ?? '暂无'),
      ],
      footer: '周报只汇总康复记录，不评价康复效果。',
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.rows,
    required this.footer,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> rows;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardTitle(icon: icon, title: title),
            const SizedBox(height: 12),
            for (final row in rows) ...[
              _MetricRow(label: row.$1, value: row.$2),
              const SizedBox(height: 8),
            ],
            Text(footer, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
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

class _PostureChip extends StatelessWidget {
  const _PostureChip({
    required this.type,
    required this.duration,
  });

  final PostureType type;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('${type.shortLabel} ${_formatDuration(duration)}'));
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

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '$hours 小时 ${minutes.toString().padLeft(2, '0')} 分钟';
  }
  return '$minutes 分钟';
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : '$value';
}
