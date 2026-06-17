import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../actions/data/rehab_repository.dart';
import '../../actions/domain/action_item.dart';
import '../domain/stage_encouragement_messages.dart';
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
      actions: actions,
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
    final reminderStatus = ref.watch(postureReminderStatusProvider);
    final postureNow =
        ref.watch(postureClockProvider).valueOrNull ?? DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        _refresh(ref);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                    session: session,
                    now: postureNow,
                    settings: settings,
                    hasMarkedDiscomfort:
                        overviewState.valueOrNull?.hasMarkedDiscomfort ?? false,
                    selectedPosture: _selectedPosture,
                    reminderStatus: reminderStatus,
                  ),
                  const SizedBox(height: 6),
                  _PostureSwitchSection(
                    activeType: session?.type,
                    selectedType: _selectedPosture,
                    reminderStatus: reminderStatus,
                    onSwitchPosture: (type) async {
                      setState(() => _selectedPosture = type);
                      if (type == PostureType.sitting ||
                          type == PostureType.standing) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '将打开系统闹钟或计时器。不同手机界面可能不同，请确认系统提醒已开始。',
                            ),
                          ),
                        );
                      }
                      await ref
                          .read(postureSessionControllerProvider.notifier)
                          .switchTo(type);
                      ref.invalidate(_homeTodayOverviewProvider);
                    },
                    onStop: () async {
                      await ref
                          .read(postureSessionControllerProvider.notifier)
                          .stopCurrent();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '如系统闹钟或计时器仍在运行，请在系统时钟中取消。',
                            ),
                          ),
                        );
                      }
                      ref.invalidate(_homeTodayOverviewProvider);
                    },
                    onComplete: () async {
                      await ref
                          .read(postureSessionControllerProvider.notifier)
                          .completeReminder();
                      ref.invalidate(_homeTodayOverviewProvider);
                    },
                    onSnooze: () async {
                      await ref
                          .read(postureSessionControllerProvider.notifier)
                          .snoozeReminder(minutes: 10);
                      ref.invalidate(_homeTodayOverviewProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
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
  const _TodayPostureSummaryCard({
    required this.summary,
  });

  final PostureSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('today-posture-summary'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '今日节奏',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            _MiniMetricGrid(
              items: [
                _MiniMetricItem(
                  label: '坐姿',
                  value: _formatShortDuration(summary.sittingTotal),
                ),
                _MiniMetricItem(
                  label: '站立',
                  value: _formatShortDuration(summary.standingTotal),
                ),
                _MiniMetricItem(
                  label: '走动',
                  value: _formatShortDuration(summary.walkingTotal),
                ),
                _MiniMetricItem(
                  label: '停止记录',
                  value: '${summary.stopCount} 次',
                  color: const Color(0xFFC39A61),
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
        mainAxisSpacing: 6,
        childAspectRatio: 3.45,
      ),
      itemBuilder: (context, index) => _MiniMetricTile(
        key: const ValueKey('today-posture-summary-metric'),
        item: items[index],
      ),
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
  const _MiniMetricTile({required this.item, super.key});

  final _MiniMetricItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 6),
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
    required this.actions,
    required this.postureSummary,
    required this.rehabSummary,
    required this.dailyNote,
  });

  final List<RehabAction> actions;
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
    required this.session,
    required this.now,
    required this.settings,
    required this.hasMarkedDiscomfort,
    required this.selectedPosture,
    required this.reminderStatus,
  });

  final RecoveryProfile? profile;
  final PostureSession? session;
  final DateTime now;
  final ReminderSettings settings;
  final bool hasMarkedDiscomfort;
  final PostureType selectedPosture;
  final String? reminderStatus;

  @override
  Widget build(BuildContext context) {
    final current = session;
    final activeType = current?.type;
    final displayType = activeType == PostureType.sitting ||
            activeType == PostureType.standing ||
            activeType == PostureType.walking
        ? activeType!
        : selectedPosture;
    final duration = current?.durationAt(now) ?? Duration.zero;
    final durationText = current == null ? '00:00' : _formatDuration(duration);
    final remainingText = _remainingText(reminderStatus);
    final greetingText = _recoveryGreeting(profile, now);
    final encouragementText = _phaseEncouragement(profile, now);
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (greetingText.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        greetingText,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
              ],
              Text(
                encouragementText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF4B5563),
                      height: 1.35,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    durationText,
                    key: const ValueKey('today-rhythm-duration'),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 78,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_postureIcon(displayType), color: statusColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    current == null
                        ? '当前状态：未计时'
                        : '当前状态：${_displayLabel(displayType)}',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: Text(
                        timerState?.statusLabel ?? '节奏正常',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _TimerInfoPanel(
                message: timerState?.message ?? '未计时',
                suggestion: reminderStatus ??
                    timerState?.suggestion ??
                    '选择坐或站，开始今天的坐站节奏。',
                elapsed: current == null ? null : durationText,
                remaining: remainingText,
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

  String _displayLabel(PostureType type) {
    return switch (type) {
      PostureType.sitting => '我在坐',
      PostureType.standing => '我在站',
      PostureType.walking => '我在走',
      PostureType.resting => '暂未开始',
    };
  }

  Color _timerToneColor(SittingStandingTimerTone tone) {
    return switch (tone) {
      SittingStandingTimerTone.blue => const Color(0xFF6B9AC4),
      SittingStandingTimerTone.yellow => const Color(0xFFC9AD65),
      SittingStandingTimerTone.orange => const Color(0xFFC58C62),
      SittingStandingTimerTone.redOrange => const Color(0xFFC77972),
      SittingStandingTimerTone.green => const Color(0xFF6F9B82),
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

  String? _remainingText(String? status) {
    if (status == null || status.contains('提醒已到期')) {
      return null;
    }
    final match = RegExp(r'剩余约 (\d+) 分钟').firstMatch(status);
    if (match == null) {
      return null;
    }
    return '约 ${match.group(1)} 分钟';
  }

  String _recoveryGreeting(RecoveryProfile? profile, DateTime now) {
    final day = profile?.postSurgeryDay(now);
    final nickname = profile?.nickname?.trim();
    if (day != null && nickname != null && nickname.isNotEmpty) {
      return '$nickname，今天是术后第 $day 天。';
    }
    if (day != null) {
      return '今天是术后第 $day 天。';
    }
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }
    return '';
  }

  String _phaseEncouragement(RecoveryProfile? profile, DateTime now) {
    final day = profile?.postSurgeryDay(now);
    if (day == null) {
      return stageEncouragementFallback;
    }
    return stageEncouragementFor(postSurgeryDay: day, now: now);
  }
}

class _TimerInfoPanel extends StatelessWidget {
  const _TimerInfoPanel({
    required this.message,
    required this.suggestion,
    this.elapsed,
    this.remaining,
  });

  final String message;
  final String suggestion;
  final String? elapsed;
  final String? remaining;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
            if (elapsed != null || remaining != null) ...[
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  if (elapsed != null) Text('已持续：$elapsed'),
                  if (remaining != null) Text('剩余：$remaining'),
                ],
              ),
            ],
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
    required this.reminderStatus,
    required this.onSwitchPosture,
    required this.onStop,
    required this.onComplete,
    required this.onSnooze,
  });

  final PostureType? activeType;
  final PostureType selectedType;
  final String? reminderStatus;
  final ValueChanged<PostureType> onSwitchPosture;
  final VoidCallback onStop;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PostureActionGrid(
              activeType: activeType,
              selectedType: selectedType,
              onSwitchPosture: onSwitchPosture,
            ),
            const SizedBox(height: 8),
            if (reminderStatus?.contains('提醒已到期') == true) ...[
              FilledButton.icon(
                key: const ValueKey('today-reminder-complete'),
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('我已处理'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('today-reminder-snooze'),
                onPressed: onSnooze,
                icon: const Icon(Icons.snooze_outlined),
                label: const Text('延后 10 分钟'),
              ),
            ] else if (activeType == PostureType.sitting ||
                activeType == PostureType.standing) ...[
              FilledButton.icon(
                key: const ValueKey('today-reminder-complete'),
                onPressed: onComplete,
                icon: Icon(activeType == PostureType.standing
                    ? Icons.event_seat_outlined
                    : Icons.directions_walk_outlined),
                label:
                    Text(activeType == PostureType.standing ? '我已坐下' : '我已起身'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('today-posture-stop'),
                onPressed: onStop,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('停止记录'),
              ),
            ] else
              OutlinedButton.icon(
                key: const ValueKey('today-posture-stop'),
                onPressed: onStop,
                icon: const Icon(Icons.self_improvement_outlined),
                label: const Text('停止记录'),
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
    const primaryPostures = [
      PostureType.sitting,
      PostureType.standing,
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: primaryPostures.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.9,
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
      key: _buttonKey(type),
      onPressed: onPressed,
      icon: Icon(_postureIcon(type), size: 22),
      label: Text(_buttonLabel(type)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Key _buttonKey(PostureType type) {
    return switch (type) {
      PostureType.sitting => const ValueKey('today-posture-sitting'),
      PostureType.walking => const ValueKey('today-posture-walking'),
      PostureType.standing => const ValueKey('today-posture-standing'),
      PostureType.resting => const ValueKey('today-posture-resting'),
    };
  }

  IconData _postureIcon(PostureType type) {
    return switch (type) {
      PostureType.sitting => Icons.event_seat_outlined,
      PostureType.standing => Icons.accessibility_new_outlined,
      PostureType.walking => Icons.directions_walk_outlined,
      PostureType.resting => Icons.self_improvement_outlined,
    };
  }

  String _buttonLabel(PostureType type) {
    return switch (type) {
      PostureType.sitting => '我在坐',
      PostureType.standing => '我在站',
      PostureType.walking => '我在走',
      PostureType.resting => '休息',
    };
  }

  Color _buttonColor(BuildContext context, PostureType type) {
    return switch (type) {
      PostureType.sitting => Theme.of(context).colorScheme.primary,
      PostureType.standing => Theme.of(context).colorScheme.primary,
      PostureType.walking => Theme.of(context).colorScheme.tertiary,
      PostureType.resting => Theme.of(context).colorScheme.tertiary,
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
