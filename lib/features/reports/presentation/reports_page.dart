import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/domain/action_item.dart';
import '../../posture/domain/posture_summary.dart';
import '../application/daily_report_controller.dart';
import '../domain/daily_report.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(dailyReportControllerProvider);
    final period = ref.watch(reportPeriodProvider);

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
        const SizedBox(height: 12),
        reportState.when(
          loading: () => const _ReportLoading(),
          error: (error, stackTrace) => _ReportError(
            onRetry: () => ref.invalidate(dailyReportControllerProvider),
          ),
          data: (report) => _ReportContent(report: report, period: period),
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
  const _ReportContent({required this.report, required this.period});

  final DailyReport report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PostureCard(summary: report.postureSummary, period: period),
        const SizedBox(height: 12),
        _RehabCard(summary: report.rehabSummary, period: period),
      ],
    );
  }
}

class _PostureCard extends StatelessWidget {
  const _PostureCard({required this.summary, required this.period});

  final PostureSummary summary;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    if (summary.sessions.isEmpty) {
      return _EmptyCard(
        icon: Icons.timer_outlined,
        title: '${period.label}坐站节奏',
        message: '当前时间范围内还没有姿势记录。开始一次坐、站、走或休息后，这里会显示汇总。',
      );
    }

    return _MetricCard(
      icon: Icons.timer_outlined,
      title: '${period.label}坐站节奏',
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

class _RehabCard extends StatelessWidget {
  const _RehabCard({required this.summary, required this.period});

  final RehabSummary summary;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    if (summary.totalCount == 0) {
      return _EmptyCard(
        icon: Icons.accessibility_new_outlined,
        title: '${period.label}康复记录',
        message: '当前时间范围内还没有康复动作记录。保存一次记录后，这里会显示汇总。',
      );
    }

    final topAction = summary.mostCompletedAction();
    final walkingTotal = summary.totalAmountForActionNamed('步行');
    final walkingDisplay = walkingTotal % 1 == 0
        ? walkingTotal.toInt().toString()
        : '$walkingTotal';

    return _MetricCard(
      icon: Icons.accessibility_new_outlined,
      title: '${period.label}康复记录',
      rows: [
        ('康复记录次数', '${summary.totalCount} 次'),
        ('步行总量', '$walkingDisplay 分钟'),
        ('做后明显加重次数', '${summary.reactionCount(RehabReaction.muchWorse)} 次'),
        ('完成最多动作', topAction?.name ?? '暂无'),
        ('需观察动作', summary.observationActionNames()),
      ],
      footer: '康复记录只用于回顾完成量和做后反应。',
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(message),
      ),
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
