import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../actions/data/rehab_repository.dart';
import '../../actions/domain/action_item.dart';
import '../../calendar/domain/calendar_day_status.dart';
import '../../milestones/data/recovery_milestone_repository.dart';
import '../../milestones/domain/recovery_milestone.dart';
import '../../posture/data/posture_session_repository.dart';
import '../../posture/domain/posture_session.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../recovery/domain/recovery_profile.dart';
import 'calendar_day_detail_page.dart';

final calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final _calendarDataProvider = FutureProvider<_CalendarData>((ref) async {
  ref.watch(appDataRefreshProvider);
  final monthStart = ref.watch(calendarMonthProvider);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1);
  final rehabRepository = ref.watch(rehabRepositoryProvider);
  final postureRepository = ref.watch(postureSessionRepositoryProvider);
  final recoveryRepository = ref.watch(recoveryRepositoryProvider);
  final milestoneRepository = ref.watch(recoveryMilestoneRepositoryProvider);

  final actions = await rehabRepository.loadActions();
  final logs = (await rehabRepository.loadAllLogs()).where((log) {
    return !log.createdAt.isBefore(monthStart) &&
        log.createdAt.isBefore(monthEnd);
  }).toList();
  final sessions = (await postureRepository.loadAll()).where((session) {
    return !session.startedAt.isBefore(monthStart) &&
        session.startedAt.isBefore(monthEnd);
  }).toList();
  final notes = await recoveryRepository.loadNotesBetween(
    start: monthStart,
    end: monthEnd,
  );
  final profile = await recoveryRepository.loadProfile();
  final milestones = (await milestoneRepository.loadMilestones()).where((item) {
    final completedAt = item.completedAt;
    return completedAt != null &&
        !completedAt.isBefore(monthStart) &&
        completedAt.isBefore(monthEnd);
  }).toList();

  return _CalendarData(
    month: monthStart,
    actions: actions,
    logs: logs,
    sessions: sessions,
    notes: notes,
    profile: profile,
    milestones: milestones,
  );
});

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_calendarDataProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '康复日历',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '看看这个月的恢复轨迹',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '刷新日历',
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () => ref.invalidate(_calendarDataProvider),
            ),
          ],
        ),
        const SizedBox(height: 16),
        state.when(
          loading: () => const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('正在读取本月记录'),
            ),
          ),
          error: (error, stackTrace) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('日历读取失败'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(_calendarDataProvider),
                child: const Text('重试'),
              ),
            ),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MonthGrid(
                data: data,
                onPreviousMonth: () => _moveMonth(ref, -1),
                onNextMonth: () => _moveMonth(ref, 1),
              ),
              if (!data.hasAnyRecord) ...[
                const SizedBox(height: 12),
                const _CalendarEmptyHint(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _moveMonth(WidgetRef ref, int delta) {
    final current = ref.read(calendarMonthProvider);
    ref.read(calendarMonthProvider.notifier).state = DateTime(
          current.year,
          current.month + delta,
        );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.data,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final _CalendarData data;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(data.month.year, data.month.month + 1, 0).day;
    final leadingBlanks = data.month.weekday - 1;
    final cells = leadingBlanks + daysInMonth;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${data.month.year} 年 ${data.month.month} 月',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('上个月'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('下个月'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final label in ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (context, index) {
                if (index < leadingBlanks) {
                  return const SizedBox.shrink();
                }

                final day = index - leadingBlanks + 1;
                final date = DateTime(data.month.year, data.month.month, day);
                final status = data.statusFor(date);
                final isToday = _isSameDay(date, DateTime.now());

                return InkWell(
                  key: ValueKey('calendar-day-${date.year}-${date.month}-$day'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CalendarDayDetailPage(status: status),
                      ),
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 5),
                        _StatusDots(dots: status.dots),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            const _CalendarLegend(),
          ],
        ),
      ),
    );
  }
}

class _StatusDots extends StatelessWidget {
  const _StatusDots({required this.dots});

  final List<CalendarStatusDot> dots;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final dot in dots.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: DecoratedBox(
              key: ValueKey('calendar-day-dot-${dot.name}'),
              decoration: BoxDecoration(
                color: calendarStatusDotColor(dot),
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 6),
            ),
          ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(dot: CalendarStatusDot.rehabAction, label: '有康复记录'),
        _LegendItem(dot: CalendarStatusDot.postureStable, label: '坐站节奏稳定'),
        _LegendItem(dot: CalendarStatusDot.postureExceeded, label: '有超时'),
        _LegendItem(dot: CalendarStatusDot.muchWorse, label: '有明显加重'),
        _LegendItem(dot: CalendarStatusDot.milestoneCompleted, label: '完成节点'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.dot, required this.label});

  final CalendarStatusDot dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          key: ValueKey('calendar-legend-dot-${dot.name}'),
          decoration: BoxDecoration(
            color: calendarStatusDotColor(dot),
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _CalendarData {
  const _CalendarData({
    required this.month,
    required this.actions,
    required this.logs,
    required this.sessions,
    required this.notes,
    required this.profile,
    required this.milestones,
  });

  final DateTime month;
  final List<RehabAction> actions;
  final List<RehabLog> logs;
  final List<PostureSession> sessions;
  final List<DailyRecoveryNote> notes;
  final RecoveryProfile? profile;
  final List<RecoveryMilestone> milestones;

  bool get hasAnyRecord {
    return logs.isNotEmpty ||
        sessions.isNotEmpty ||
        notes.isNotEmpty ||
        milestones.isNotEmpty;
  }

  CalendarDayStatus statusFor(DateTime date) {
    return CalendarDayStatus(
      date: date,
      actions: actions,
      rehabLogs: logs.where((log) => _isSameDay(log.createdAt, date)).toList(),
      postureSessions: sessions
          .where((session) => _isSameDay(session.startedAt, date))
          .toList(),
      note: notes.cast<DailyRecoveryNote?>().firstWhere(
            (note) => note != null && _isSameDay(note.date, date),
            orElse: () => null,
          ),
      profile: profile,
      milestones: milestones.where((milestone) {
        final completedAt = milestone.completedAt;
        return completedAt != null && _isSameDay(completedAt, date);
      }).toList(),
    );
  }
}

class _CalendarEmptyHint extends StatelessWidget {
  const _CalendarEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.edit_calendar_outlined, color: Color(0xFF3498DB)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '这个月还没有记录。记录一点也有价值。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color calendarStatusDotColor(CalendarStatusDot dot) {
  return switch (dot) {
    CalendarStatusDot.none => const Color(0xFFCBD5E1),
    CalendarStatusDot.rehabAction => const Color(0xFF3498DB),
    CalendarStatusDot.postureStable => const Color(0xFF27AE60),
    CalendarStatusDot.postureExceeded => const Color(0xFFF2994A),
    CalendarStatusDot.muchWorse => const Color(0xFFEB5757),
    CalendarStatusDot.milestoneCompleted => const Color(0xFF9B51E0),
  };
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
