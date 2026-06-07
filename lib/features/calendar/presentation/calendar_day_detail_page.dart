import 'package:flutter/material.dart';

import '../../actions/domain/action_item.dart';
import '../../calendar/domain/calendar_day_status.dart';
import '../../recovery/domain/daily_recovery_note.dart';

class CalendarDayDetailPage extends StatelessWidget {
  const CalendarDayDetailPage({super.key, required this.status});

  final CalendarDayStatus status;

  @override
  Widget build(BuildContext context) {
    final postSurgeryDay = status.postSurgeryDay;

    return Scaffold(
      appBar: AppBar(title: const Text('当天详情')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _dateTitle(status.date, postSurgeryDay),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          if (!status.hasAnyRecord)
            const _DayEmptyState()
          else ...[
            _DailyStatusCard(note: status.note),
            const SizedBox(height: 12),
            _PostureCard(status: status),
            const SizedBox(height: 12),
            _RehabLogsCard(status: status),
            if (status.hasMuchWorse) ...[
              const SizedBox(height: 12),
              const _GentleNoticeCard(),
            ],
            if (status.completedMilestones.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MilestoneCard(status: status),
            ],
          ],
        ],
      ),
    );
  }

  String _dateTitle(DateTime date, int? postSurgeryDay) {
    final dayText = '${date.year}年${date.month}月${date.day}日';
    if (postSurgeryDay == null) {
      return dayText;
    }
    return '$dayText · 术后第$postSurgeryDay天';
  }
}

class _DailyStatusCard extends StatelessWidget {
  const _DailyStatusCard({required this.note});

  final DailyRecoveryNote? note;

  @override
  Widget build(BuildContext context) {
    final value = note;

    return _SectionCard(
      title: '每日状态',
      children: value == null
          ? const [Text('这一天还没有记录每日状态。')]
          : [
              _MetricLine(label: '整体感觉', value: value.overallFeeling.label),
              _MetricLine(label: '腰痛评分', value: '${value.backPainScore}/10'),
              _MetricLine(
                label: '腿部症状评分',
                value: '${value.legSymptomScore}/10',
              ),
              _MetricLine(label: '疲劳评分', value: '${value.fatigueScore}/10'),
              _MetricLine(
                label: '标签',
                value: value.tags.isEmpty ? '未填写' : value.tags.join('、'),
              ),
              if (value.note != null && value.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(value.note!),
                ),
            ],
    );
  }
}

class _PostureCard extends StatelessWidget {
  const _PostureCard({required this.status});

  final CalendarDayStatus status;

  @override
  Widget build(BuildContext context) {
    final summary = status.postureSummary;

    return _SectionCard(
      title: '坐站节奏',
      children: [
        _MetricLine(
          label: '最长连续坐姿',
          value: _formatDuration(summary.longestSitting),
        ),
        _MetricLine(label: '久坐中断次数', value: '${summary.sittingBreakCount} 次'),
        _MetricLine(label: '久坐超时次数', value: '${summary.sittingOverThresholdCount} 次'),
        _MetricLine(
          label: '坐姿累计',
          value: _formatDuration(summary.sittingTotal),
        ),
      ],
    );
  }
}

class _RehabLogsCard extends StatelessWidget {
  const _RehabLogsCard({required this.status});

  final CalendarDayStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.rehabLogs.isEmpty) {
      return const _SectionCard(
        title: '康复动作',
        children: [Text('这一天还没有记录康复动作。')],
      );
    }

    return _SectionCard(
      title: '康复动作',
      children: [
        for (final log in status.rehabLogs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.actionNameFor(log.actionId),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatNumber(log.amountValue)} ${log.unit} · ${log.reaction.label}',
                ),
                if (log.symptomTags.isNotEmpty)
                  Text('症状标签：${log.symptomTags.join('、')}'),
                if (log.note != null && log.note!.isNotEmpty) Text(log.note!),
              ],
            ),
          ),
      ],
    );
  }
}

class _GentleNoticeCard extends StatelessWidget {
  const _GentleNoticeCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFFFFF1F0),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('这一天有明显加重记录，可作为后续观察参考。必要时请咨询医生或康复师。'),
      ),
    );
  }
}

class _DayEmptyState extends StatelessWidget {
  const _DayEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(
              Icons.event_note_outlined,
              size: 42,
              color: Color(0xFF3498DB),
            ),
            const SizedBox(height: 12),
            Text(
              '这一天还没有记录。',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text('记录一点也有价值。'),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.status});

  final CalendarDayStatus status;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '康复节点',
      children: [
        for (final milestone in status.completedMilestones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('已完成：${milestone.title}'),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) {
    return '$minutes 分钟';
  }
  return '$hours 小时 $minutes 分钟';
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
