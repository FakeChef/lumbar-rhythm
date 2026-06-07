import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/data/rehab_repository.dart';
import '../../actions/domain/action_item.dart';
import '../../posture/application/posture_session_controller.dart';
import '../../posture/data/posture_session_repository.dart';
import '../../posture/domain/posture_session.dart';
import '../../posture/domain/posture_summary.dart';
import '../../posture/domain/sitting_standing_timer_state.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../settings/application/reminder_settings_controller.dart';
import '../../settings/domain/reminder_settings.dart';

final _homeTodayOverviewProvider = FutureProvider<_HomeTodayOverview>(
  (ref) async {
    final now = DateTime.now();
    final rehabRepository = ref.watch(rehabRepositoryProvider);
    final actions = await rehabRepository.loadActions();
    final logs = await rehabRepository.loadToday(now: now);
    final sessions =
        await ref.watch(postureSessionRepositoryProvider).loadToday(now: now);
    final note = await ref.watch(recoveryRepositoryProvider).loadNote(now);
    return _HomeTodayOverview(
      postureSummary: PostureSummary(sessions: sessions, now: now),
      rehabSummary: RehabSummary(logs: logs, actions: actions),
      dailyNote: note,
    );
  },
);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  PostureType _selectedPosture = PostureType.sitting;

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(reminderSettingsControllerProvider);
    final postureState = ref.watch(postureSessionControllerProvider);
    final overviewState = ref.watch(_homeTodayOverviewProvider);
    final postureNow =
        ref.watch(postureClockProvider).valueOrNull ?? DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        _refresh(ref);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          settingsState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取提醒设置'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '提醒设置读取失败',
              onRetry: () => ref.invalidate(reminderSettingsControllerProvider),
            ),
            data: (settings) => postureState.when(
              loading: () => const _HomeLoadingCard(title: '正在读取当前姿势'),
              error: (error, stackTrace) => _HomeErrorCard(
                title: '当前姿势读取失败',
                onRetry: () => ref.invalidate(postureSessionControllerProvider),
              ),
              data: (session) => Column(
                children: [
                  _PostureStatusCard(
                    session: session,
                    now: postureNow,
                    settings: settings,
                    hasMarkedDiscomfort:
                        overviewState.valueOrNull?.hasMarkedDiscomfort ??
                            false,
                    selectedPosture: _selectedPosture,
                    onEndCurrent: () async {
                      await ref
                          .read(postureSessionControllerProvider.notifier)
                          .endCurrent();
                      ref.invalidate(_homeTodayOverviewProvider);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PostureSwitchSection(
                    activeType: session?.type,
                    selectedType: _selectedPosture,
                    onSwitchPosture: (type) async {
                      setState(() => _selectedPosture = type);
                      await ref
                          .read(postureSessionControllerProvider.notifier)
                          .switchTo(type);
                      ref.invalidate(_homeTodayOverviewProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          overviewState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取今日摘要'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '今日摘要读取失败',
              onRetry: () => ref.invalidate(_homeTodayOverviewProvider),
            ),
            data: (overview) => _TodayPostureSummaryCard(
              summary: overview.postureSummary,
            ),
          ),
        ],
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(postureSessionControllerProvider);
    ref.invalidate(reminderSettingsControllerProvider);
    ref.invalidate(_homeTodayOverviewProvider);
  }
}

class _TodayPostureSummaryCard extends StatelessWidget {
  const _TodayPostureSummaryCard({required this.summary});

  final PostureSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '今日坐站摘要',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            _MiniMetricGrid(
              items: [
                _MiniMetricItem(
                  label: '今日最长坐姿',
                  value: _formatShortDuration(summary.longestSitting),
                ),
                _MiniMetricItem(
                  label: '今日最长站立',
                  value: _formatShortDuration(summary.longestStanding),
                ),
                _MiniMetricItem(
                  label: '今日打断次数',
                  value: '${summary.switchCount} 次',
                ),
                _MiniMetricItem(
                  label: '今日超时次数',
                  value:
                      '${summary.sittingOverThresholdCount + summary.standingOverThresholdCount} 次',
                  color: const Color(0xFFF2994A),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetricGrid extends StatelessWidget {
  const _MiniMetricGrid({required this.items});

  final List<_MiniMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (context, index) => _MiniMetricTile(item: items[index]),
    );
  }
}

class _MiniMetricItem {
  const _MiniMetricItem({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;
}

class _MiniMetricTile extends StatelessWidget {
  const _MiniMetricTile({required this.item});

  final _MiniMetricItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftLine extends StatelessWidget {
  const _SoftLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _HomeTodayOverview {
  const _HomeTodayOverview({
    required this.postureSummary,
    required this.rehabSummary,
    required this.dailyNote,
  });

  final PostureSummary postureSummary;
  final RehabSummary rehabSummary;
  final DailyRecoveryNote? dailyNote;

  bool get hasMarkedDiscomfort {
    return rehabSummary.reactionCount(RehabReaction.muchWorse) > 0 ||
        (dailyNote?.overallFeeling == OverallFeeling.slightlyWorse) ||
        (dailyNote?.backPainScore ?? 0) >= 7 ||
        (dailyNote?.legSymptomScore ?? 0) >= 7 ||
        (dailyNote?.fatigueScore ?? 0) >= 7;
  }
}

class _PostureStatusCard extends StatelessWidget {
  const _PostureStatusCard({
    required this.session,
    required this.now,
    required this.settings,
    required this.hasMarkedDiscomfort,
    required this.selectedPosture,
    required this.onEndCurrent,
  });

  final PostureSession? session;
  final DateTime now;
  final ReminderSettings settings;
  final bool hasMarkedDiscomfort;
  final PostureType selectedPosture;
  final VoidCallback onEndCurrent;

  @override
  Widget build(BuildContext context) {
    final current = session;
    final activeType = current?.type;
    final displayType = activeType ?? selectedPosture;
    final duration = current?.durationAt(now) ?? Duration.zero;
    final durationText = current == null ? '00:00' : _formatDuration(duration);
    final timerState = current == null
        ? null
        : SittingStandingTimerState.calculate(
            posture: displayType,
            elapsed: duration,
            settings: settings,
            hasMarkedDiscomfort: hasMarkedDiscomfort,
          );
    final statusColor = timerState == null
        ? _timerToneColor(SittingStandingTimerTone.blue)
        : _timerToneColor(timerState.tone);

    return KeyedSubtree(
      key: const Key('today-rhythm-timer'),
      child: Card(
        key: const ValueKey('today-rhythm-card'),
        color: statusColor.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _postureIcon(displayType),
                      color: statusColor,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '坐站节奏',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '久坐久站提醒器',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  durationText,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              current == null ? '尚未开始' : '当前姿势：${current.type.label}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Text(
                    timerState?.statusLabel ?? '节奏正常',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _TimerInfoPanel(
              message: timerState?.message ?? '开始后会显示距离提醒的时间',
              suggestion: timerState?.suggestion ?? '选择一个姿势，按自己的节奏开始记录。',
            ),
            if (current != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onEndCurrent,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('结束当前状态'),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _postureIcon(PostureType type) {
    return switch (type) {
      PostureType.sitting => Icons.event_seat_outlined,
      PostureType.standing => Icons.accessibility_new_outlined,
      PostureType.walking => Icons.directions_walk_outlined,
      PostureType.resting => Icons.self_improvement_outlined,
    };
  }

  Color _timerToneColor(SittingStandingTimerTone tone) {
    return switch (tone) {
      SittingStandingTimerTone.blue => const Color(0xFF2E86C1),
      SittingStandingTimerTone.yellow => const Color(0xFFF2C94C),
      SittingStandingTimerTone.orange => const Color(0xFFF2994A),
      SittingStandingTimerTone.redOrange => const Color(0xFFEB5757),
      SittingStandingTimerTone.green => const Color(0xFF27AE60),
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TimerInfoPanel extends StatelessWidget {
  const _TimerInfoPanel({
    required this.message,
    required this.suggestion,
  });

  final String message;
  final String suggestion;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SoftLine(label: '提醒时间', value: message),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(suggestion)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostureSwitchSection extends StatelessWidget {
  const _PostureSwitchSection({
    required this.activeType,
    required this.selectedType,
    required this.onSwitchPosture,
  });

  final PostureType? activeType;
  final PostureType selectedType;
  final ValueChanged<PostureType> onSwitchPosture;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '切换当前姿势',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _PostureActionGrid(
              activeType: activeType,
              selectedType: selectedType,
              onSwitchPosture: onSwitchPosture,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostureActionGrid extends StatelessWidget {
  const _PostureActionGrid({
    required this.activeType,
    required this.selectedType,
    required this.onSwitchPosture,
  });

  final PostureType? activeType;
  final PostureType selectedType;
  final ValueChanged<PostureType> onSwitchPosture;

  @override
  Widget build(BuildContext context) {
    const primaryPostures = [PostureType.sitting, PostureType.standing];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: primaryPostures.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final type = primaryPostures[index];
        return _PostureActionButton(
          type: type,
          isActive: activeType == type,
          isSelected: selectedType == type,
          onPressed: () => onSwitchPosture(type),
        );
      },
    );
  }
}

class _PostureActionButton extends StatelessWidget {
  const _PostureActionButton({
    required this.type,
    required this.isActive,
    required this.isSelected,
    required this.onPressed,
  });

  final PostureType type;
  final bool isActive;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _buttonColor(context, type);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(_postureIcon(type), size: 22),
      label: Text(type.label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: isActive
            ? color.withValues(alpha: 0.16)
            : scheme.surface.withValues(alpha: 0.74),
        foregroundColor: isActive ? color : scheme.onSurface,
        side: BorderSide(
          color: isActive || isSelected ? color : scheme.outlineVariant,
          width: isActive ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  IconData _postureIcon(PostureType type) {
    return switch (type) {
      PostureType.sitting => Icons.event_seat_outlined,
      PostureType.standing => Icons.accessibility_new_outlined,
      PostureType.walking => Icons.directions_walk_outlined,
      PostureType.resting => Icons.self_improvement_outlined,
    };
  }

  Color _buttonColor(BuildContext context, PostureType type) {
    return switch (type) {
      PostureType.sitting => const Color(0xFF2E86C1),
      PostureType.standing => const Color(0xFF2E86C1),
      PostureType.walking => const Color(0xFF27AE60),
      PostureType.resting => const Color(0xFF27AE60),
    };
  }
}

class _HomeLoadingCard extends StatelessWidget {
  const _HomeLoadingCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(title),
      ),
    );
  }
}

class _HomeErrorCard extends StatelessWidget {
  const _HomeErrorCard({
    required this.title,
    required this.onRetry,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(title),
        trailing: TextButton(
          onPressed: onRetry,
          child: const Text('重试'),
        ),
      ),
    );
  }
}

String _formatShortDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) {
    return '$hours 小时 $minutes 分';
  }
  if (hours > 0) {
    return '$hours 小时';
  }
  return '$minutes 分';
}
