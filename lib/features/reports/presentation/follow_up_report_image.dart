import 'package:flutter/material.dart';

import '../../actions/domain/action_item.dart';
import '../domain/daily_report.dart';

const followUpReportDisclaimer = '本报告仅用于个人康复记录回顾，不作为专业判断依据。';

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
    final rehab =
        useCurrentRange ? report.rehabSummary : report.recentRehabSummary;
    final logs = useCurrentRange ? report.rehabLogs : report.recentRehabLogs;
    final nickname = report.profile?.nickname?.trim();
    final postSurgeryDay = report.postSurgeryDay(generatedAt);
    final recordedDays = {
      for (final log in logs) _dateKey(log.createdAt),
    }.length;
    final aerobicMinutes = _aerobicMinutes(logs, report.rehabActions);
    final topAction = rehab.mostCompletedAction()?.name ?? '暂无';
    final sortedLogs = [...logs]
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

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
                '腰椎节奏康复活动报告',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF24313B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '本地康复记录',
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
                title: '康复动作汇总',
                child: _MetricGrid(
                  items: [
                    _MetricData(label: '记录天数', value: '$recordedDays 天'),
                    _MetricData(
                      label: '步行/有氧分钟数',
                      value: '${_formatNumber(aerobicMinutes)} 分钟',
                    ),
                    _MetricData(
                      label: '动作记录次数',
                      value: '${rehab.totalCount} 次',
                    ),
                    _MetricData(
                      label: '记录最多的动作',
                      value: topAction,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FollowUpSection(
                title: '动作记录',
                child: sortedLogs.isEmpty
                    ? const _EmptyText('暂无康复动作记录')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final log in sortedLogs.take(10))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '${_formatDate(log.createdAt)}  '
                                '${_actionNameFor(report, log.actionId)}  '
                                '${_formatNumber(log.amountValue)} ${log.unit}  '
                                '${log.reaction.label}',
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

String _dateKey(DateTime value) {
  return '${value.year}-${value.month}-${value.day}';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

double _aerobicMinutes(List<RehabLog> logs, List<RehabAction> actions) {
  final actionsById = {
    for (final action in actions) action.id: action,
  };
  return logs.where((log) {
    final category = actionsById[log.actionId]?.category;
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
