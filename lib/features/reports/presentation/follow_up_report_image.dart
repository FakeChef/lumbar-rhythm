import 'package:flutter/material.dart';

import '../../actions/domain/action_item.dart';
import '../domain/daily_report.dart';

const followUpReportDisclaimer =
    '本报告仅用于个人康复记录回顾，不作为专业判断依据。';

class FollowUpReportImage extends StatelessWidget {
  const FollowUpReportImage({
    required this.report,
    required this.generatedAt,
    this.rangeLabel = '最近 7 天',
    this.useCurrentRange = false,
    super.key,
  });

  final DailyReport report;
  final DateTime generatedAt;
  final String rangeLabel;
  final bool useCurrentRange;

  @override
  Widget build(BuildContext context) {
    final posture =
        useCurrentRange ? report.postureSummary : report.recentPostureSummary;
    final rehab =
        useCurrentRange ? report.rehabSummary : report.recentRehabSummary;
    final logs = useCurrentRange ? report.rehabLogs : report.recentRehabLogs;
    final notes = useCurrentRange ? report.dailyNotes : report.recentDailyNotes;
    final nickname = report.profile?.nickname?.trim();
    final postSurgeryDay = report.postSurgeryDay(generatedAt);
    final recordedDays = {
      for (final log in logs) _dateKey(log.createdAt),
    }.length;
    final maxBackPain = _maxScore(notes.map((note) => note.backPainScore));
    final maxLegSymptom =
        _maxScore(notes.map((note) => note.legSymptomScore));
    final maxFatigue = _maxScore(notes.map((note) => note.fatigueScore));
    final commonTags = _commonSymptomTags(
      logs,
      notes.expand((note) => note.tags),
    );
    final noteSummaries = notes
        .where((note) => note.note?.trim().isNotEmpty ?? false)
        .toList()
      ..sort((left, right) => right.date.compareTo(left.date));

    return Material(
      color: Colors.white,
      child: Container(
        color: const Color(0xFFF7F9FB),
        padding: const EdgeInsets.all(28),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFF1E2933),
            fontSize: 16,
            height: 1.4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '腰椎节奏复诊记录摘要',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF24313B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '本地记录摘要',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF52616D),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _FollowUpSection(
                title: '基础信息',
                child: Column(
                  children: [
                    if (nickname != null && nickname.isNotEmpty)
                      _InfoRow(label: '昵称', value: nickname),
                    if (postSurgeryDay != null)
                      _InfoRow(
                        label: '术后记录',
                        value: '术后第 $postSurgeryDay 天',
                      ),
                    _InfoRow(label: '报告范围', value: rangeLabel),
                    _InfoRow(
                      label: '生成日期',
                      value: _formatDate(generatedAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FollowUpSection(
                title: '坐走节奏',
                child: _MetricGrid(
                  items: [
                    _MetricData(
                      label: '最长连续坐姿',
                      value: _formatDuration(posture.longestSitting),
                    ),
                    _MetricData(
                      label: '最长连续走动',
                      value: _formatDuration(posture.longestWalking),
                    ),
                    _MetricData(
                      label: '坐走提醒次数',
                      value: '${posture.rhythmReminderCount} 次',
                    ),
                    _MetricData(
                      label: '停止记录次数',
                      value: '${posture.stopCount} 次',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FollowUpSection(
                title: '康复活动',
                child: _MetricGrid(
                  items: [
                    _MetricData(label: '记录天数', value: '$recordedDays 天'),
                    _MetricData(
                      label: '步行总分钟数',
                      value:
                          '${_formatNumber(rehab.totalAmountForActionNamed('平地步行'))} 分钟',
                    ),
                    _MetricData(
                      label: '康复活动记录次数',
                      value: '${rehab.totalCount} 次',
                    ),
                    _MetricData(
                      label: '明显加重记录次数',
                      value:
                          '${rehab.reactionCount(RehabReaction.muchWorse)} 次',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FollowUpSection(
                title: '身体状态',
                child: Column(
                  children: [
                    _ScoreLine(label: '腰部不适最高分', value: maxBackPain),
                    _ScoreLine(label: '腿部症状最高分', value: maxLegSymptom),
                    _ScoreLine(label: '疲劳最高分', value: maxFatigue),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: '常见症状标签',
                      value: commonTags.isEmpty ? '暂无症状标签记录' : commonTags,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FollowUpSection(
                title: '备注摘要',
                child: noteSummaries.isEmpty
                    ? const _EmptyText('暂无备注记录')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final note in noteSummaries.take(5))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '${_formatDate(note.date)}  ${note.note!.trim()}',
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 22),
              const Text(
                followUpReportDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF52616D),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUpSection extends StatelessWidget {
  const _FollowUpSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF365A76),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricData> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24313B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF52616D),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF52616D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      label: label,
      value: value == null ? '暂无记录' : '$value / 10',
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF52616D)),
    );
  }
}

int? _maxScore(Iterable<int> values) {
  if (values.isEmpty) return null;
  return values.reduce((left, right) => left > right ? left : right);
}

String _commonSymptomTags(
  List<RehabLog> logs,
  Iterable<String> dailyNoteTags,
) {
  final counts = <String, int>{};
  for (final log in logs) {
    final tags = log.symptomTags.isNotEmpty
        ? log.symptomTags
        : [if (log.symptomTag?.trim().isNotEmpty ?? false) log.symptomTag!];
    for (final tag in tags) {
      final cleaned = tag.trim();
      if (cleaned.isNotEmpty) {
        counts[cleaned] = (counts[cleaned] ?? 0) + 1;
      }
    }
  }
  for (final tag in dailyNoteTags) {
    final cleaned = tag.trim();
    if (cleaned.isNotEmpty) {
      counts[cleaned] = (counts[cleaned] ?? 0) + 1;
    }
  }
  final entries = counts.entries.toList()
    ..sort((left, right) {
      final countOrder = right.value.compareTo(left.value);
      return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
    });
  return entries.take(5).map((entry) => entry.key).join('、');
}

String _dateKey(DateTime value) {
  return '${value.year}-${value.month}-${value.day}';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) return '$hours 小时 $minutes 分';
  if (hours > 0) return '$hours 小时';
  return '$minutes 分钟';
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
