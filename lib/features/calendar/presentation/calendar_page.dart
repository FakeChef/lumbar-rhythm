import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/data/rehab_repository.dart';
import '../../actions/domain/action_item.dart';
import '../../posture/data/posture_session_repository.dart';
import '../../posture/domain/posture_session.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../recovery/domain/daily_recovery_note.dart';

final _calendarDataProvider = FutureProvider<_CalendarData>((ref) async {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);
  final monthEnd = DateTime(now.year, now.month + 1);
  final rehabRepository = ref.watch(rehabRepositoryProvider);
  final postureRepository = ref.watch(postureSessionRepositoryProvider);
  final recoveryRepository = ref.watch(recoveryRepositoryProvider);
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

  return _CalendarData(
    month: monthStart,
    actions: actions,
    logs: logs,
    sessions: sessions,
    notes: notes,
  );
});

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_calendarDataProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '日历',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
            children: [
              _MonthGrid(
                data: data,
                selectedDate: _selectedDate,
                onSelected: (date) => setState(() => _selectedDate = date),
              ),
              const SizedBox(height: 12),
              _DaySummaryCard(data: data, selectedDate: _selectedDate),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.data,
    required this.selectedDate,
    required this.onSelected,
  });

  final _CalendarData data;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

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
            Text(
              '${data.month.year} 年 ${data.month.month} 月',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final label in ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(child: Center(child: Text(label))),
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
                final hasRecord = data.hasAnyRecord(date);
                final selected = _isSameDay(date, selectedDate);

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelected(date),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day'),
                        const SizedBox(height: 4),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: hasRecord
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(dimension: 6),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.data, required this.selectedDate});

  final _CalendarData data;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final logs = data.logsFor(selectedDate);
    final sessions = data.sessionsFor(selectedDate);
    final note = data.noteFor(selectedDate);
    final walkingMinutes = data.walkingMinutesFor(selectedDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${selectedDate.month} 月 ${selectedDate.day} 日',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _MetricLine(label: '康复动作记录', value: '${logs.length} 次'),
            _MetricLine(
                label: '步行总量', value: '${_formatNumber(walkingMinutes)} 分钟'),
            _MetricLine(label: '坐站记录段数', value: '${sessions.length} 段'),
            _MetricLine(
              label: '今日小结',
              value: note == null ? '未记录' : note.overallFeeling.label,
            ),
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

class _CalendarData {
  const _CalendarData({
    required this.month,
    required this.actions,
    required this.logs,
    required this.sessions,
    required this.notes,
  });

  final DateTime month;
  final List<RehabAction> actions;
  final List<RehabLog> logs;
  final List<PostureSession> sessions;
  final List<DailyRecoveryNote> notes;

  bool hasAnyRecord(DateTime date) {
    return logsFor(date).isNotEmpty ||
        sessionsFor(date).isNotEmpty ||
        noteFor(date) != null;
  }

  List<RehabLog> logsFor(DateTime date) {
    return logs.where((log) => _isSameDay(log.createdAt, date)).toList();
  }

  List<PostureSession> sessionsFor(DateTime date) {
    return sessions
        .where((session) => _isSameDay(session.startedAt, date))
        .toList();
  }

  DailyRecoveryNote? noteFor(DateTime date) {
    for (final note in notes) {
      if (_isSameDay(note.date, date)) {
        return note;
      }
    }
    return null;
  }

  double walkingMinutesFor(DateTime date) {
    final walkingActionIds = actions
        .where((action) => action.name == '步行')
        .map((action) => action.id)
        .toSet();
    return logsFor(date)
        .where((log) => walkingActionIds.contains(log.actionId))
        .map((log) => log.amountValue)
        .fold(0.0, (sum, value) => sum + value);
  }
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
