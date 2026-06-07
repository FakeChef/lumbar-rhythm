import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../actions/data/rehab_repository.dart';
import '../../actions/domain/action_item.dart';
import '../../posture/application/posture_session_controller.dart';
import '../../posture/data/posture_session_repository.dart';
import '../../posture/domain/posture_session.dart';
import '../../posture/domain/posture_summary.dart';
import '../../posture/domain/sitting_standing_timer_state.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../recovery/domain/recovery_profile.dart';
import '../../settings/application/reminder_settings_controller.dart';
import '../../settings/domain/reminder_settings.dart';

final _homeRecoveryProfileProvider = FutureProvider((ref) {
  ref.watch(appDataRefreshProvider);
  return ref.watch(recoveryRepositoryProvider).loadProfile();
});

final todayEncouragementProvider = Provider<String>((ref) {
  final now = DateTime.now();
  final index = now.microsecondsSinceEpoch % todayEncouragements.length;
  return todayEncouragements[index];
});

const todayEncouragements = [
  '今天不用完美，记录一点也有价值。',
  '稳定比激进更重要。',
  '慢一点，也是在往前走。',
  '换个姿势，是给身体一个缓冲。',
  '恢复不是比赛，按自己的节奏来。',
  '小小的坚持，也值得被看见。',
  '今天照顾好自己，就已经很好。',
  '每一次记录，都是更了解自己的方式。',
  '温和一点，身体也会更安心。',
  '按下开始，就算完成了一个小行动。',
  '给自己一点耐心，节奏会慢慢稳定。',
  '先做好当下这一小步。',
  '身体的反馈，值得被认真听见。',
  '不急着比较，专注自己的节奏。',
  '短暂起身，也是在照顾今天的状态。',
  '能记录下来，就是很好的开始。',
  '今天的目标可以很小，也可以很踏实。',
  '给腰背一点缓冲，也给自己一点余地。',
  '平稳的一天，同样值得记录。',
  '照顾自己，是一件可以慢慢做的事。',
];

final _homeTodayOverviewProvider = FutureProvider<_HomeTodayOverview>(
  (ref) async {
    ref.watch(appDataRefreshProvider);
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
    final recoveryProfileState = ref.watch(_homeRecoveryProfileProvider);
    final overviewState = ref.watch(_homeTodayOverviewProvider);
    final encouragement = ref.watch(todayEncouragementProvider);
    final postureNow =
        ref.watch(postureClockProvider).valueOrNull ?? DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        _refresh(ref);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                    profile: recoveryProfileState.valueOrNull,
                    encouragement: encouragement,
                    session: session,
                    now: postureNow,
                    settings: settings,
                    hasMarkedDiscomfort:
                        overviewState.valueOrNull?.hasMarkedDiscomfort ??
                            false,
                    selectedPosture: _selectedPosture,
                  ),
                  const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '今日坐站摘要',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
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
        childAspectRatio: 2.7,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    required this.profile,
    required this.encouragement,
    required this.session,
    required this.now,
    required this.settings,
    required this.hasMarkedDiscomfort,
    required this.selectedPosture,
  });

  final RecoveryProfile? profile;
  final String encouragement;
  final PostureSession? session;
  final DateTime now;
  final ReminderSettings settings;
  final bool hasMarkedDiscomfort;
  final PostureType selectedPosture;

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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              _recoveryGreeting(profile, now),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              encouragement,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B5563),
                  ),
            ),
            const SizedBox(height: 10),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  durationText,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_postureIcon(displayType), color: statusColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  current == null ? '尚未开始' : '当前姿势：${current.type.label}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      timerState?.statusLabel ?? '节奏正常',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TimerInfoPanel(
              message: timerState?.message ?? '开始后会显示距离提醒的时间',
              suggestion: timerState?.suggestion ?? '选择一个姿势，按自己的节奏开始记录。',
            ),
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

  String _recoveryGreeting(RecoveryProfile? profile, DateTime now) {
    final day = profile?.postSurgeryDay(now);
    if (day == null) {
      return '可在设置中添加手术日期。';
    }
    final nickname = profile?.nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) {
      return '$nickname，今天是术后第 $day 天。';
    }
    return '今天是术后第 $day 天。';
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              suggestion,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
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
        padding: const EdgeInsets.all(10),
        child: _PostureActionGrid(
          activeType: activeType,
          selectedType: selectedType,
          onSwitchPosture: onSwitchPosture,
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
        childAspectRatio: 3.1,
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
