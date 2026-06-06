import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../actions/data/rehab_repository.dart';
import '../../actions/domain/action_item.dart';
import '../../posture/application/posture_session_controller.dart';
import '../../posture/data/posture_session_repository.dart';
import '../../posture/domain/posture_session.dart';
import '../../posture/domain/posture_summary.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../recovery/domain/recovery_profile.dart';
import '../../reports/application/daily_report_controller.dart';
import '../../settings/application/reminder_settings_controller.dart';
import '../../settings/domain/reminder_settings.dart';

final _homeRecoveryProfileProvider = FutureProvider((ref) {
  return ref.watch(recoveryRepositoryProvider).loadProfile();
});

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
    final recoveryProfileState = ref.watch(_homeRecoveryProfileProvider);
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
          recoveryProfileState.when(
            loading: () => _HomeHeader(
              subtitle: '正在读取康复资料',
              onRefresh: () => _refresh(ref),
            ),
            error: (error, stackTrace) => _HomeHeader(
              subtitle: '可在设置中添加手术日期',
              onRefresh: () => _refresh(ref),
            ),
            data: (profile) => _HomeHeader(
              subtitle: _recoveryDayText(profile),
              onRefresh: () => _refresh(ref),
            ),
          ),
          const SizedBox(height: 20),
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
              data: (session) => _PostureStatusCard(
                session: session,
                now: postureNow,
                settings: settings,
                selectedPosture: _selectedPosture,
                onSelectedPostureChanged: (type) {
                  if (type != null) {
                    setState(() => _selectedPosture = type);
                  }
                },
                onStartOrSwitch: () async {
                  await ref
                      .read(postureSessionControllerProvider.notifier)
                      .switchTo(_selectedPosture);
                },
                onEndCurrent: () async {
                  await ref
                      .read(postureSessionControllerProvider.notifier)
                      .endCurrent();
                },
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
          const SizedBox(height: 12),
          overviewState.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (overview) => _TodayRecoveryOverviewCard(
              overview: overview,
              onEditNote: () => _showDailyRecoveryNoteDialog(context),
            ),
          ),
          const SizedBox(height: 12),
          _QuickEntryCard(
            onOpenCalendar: () => widget.onOpenTab?.call(1),
            onOpenRehab: () => widget.onOpenTab?.call(2),
            onOpenReport: () => widget.onOpenTab?.call(3),
          ),
        ],
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(postureSessionControllerProvider);
    ref.invalidate(reminderSettingsControllerProvider);
    ref.invalidate(_homeRecoveryProfileProvider);
    ref.invalidate(_homeTodayOverviewProvider);
  }

  Future<void> _showDailyRecoveryNoteDialog(BuildContext context) async {
    final repository = ref.read(recoveryRepositoryProvider);
    final today = DateTime.now();
    final existing = await repository.loadNote(today);
    if (!context.mounted) return;

    var feeling = existing?.overallFeeling ?? OverallFeeling.same;
    var backPain = existing?.backPainScore ?? 0;
    var legSymptom = existing?.legSymptomScore ?? 0;
    var fatigue = existing?.fatigueScore ?? 0;
    var note = existing?.note ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('今日康复小结'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<OverallFeeling>(
                      initialValue: feeling,
                      decoration: const InputDecoration(labelText: '总体感觉'),
                      items: [
                        for (final value in OverallFeeling.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => feeling = value);
                        }
                      },
                    ),
                    _ScoreSlider(
                      label: '腰部不适',
                      value: backPain,
                      onChanged: (value) =>
                          setDialogState(() => backPain = value),
                    ),
                    _ScoreSlider(
                      label: '腿部症状',
                      value: legSymptom,
                      onChanged: (value) =>
                          setDialogState(() => legSymptom = value),
                    ),
                    _ScoreSlider(
                      label: '疲劳感',
                      value: fatigue,
                      onChanged: (value) =>
                          setDialogState(() => fatigue = value),
                    ),
                    TextFormField(
                      initialValue: note,
                      decoration: const InputDecoration(labelText: '备注（可选）'),
                      maxLines: 3,
                      onChanged: (value) => note = value,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(this.context);
    await repository.saveNote(
      date: today,
      overallFeeling: feeling,
      backPainScore: backPain,
      legSymptomScore: legSymptom,
      fatigueScore: fatigue,
      note: note,
    );
    ref.invalidate(dailyReportControllerProvider);
    ref.invalidate(_homeTodayOverviewProvider);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('已保存今日康复小结')),
    );
  }

  String _recoveryDayText(RecoveryProfile? profile) {
    final day = profile?.postSurgeryDay(DateTime.now());
    return day == null ? '可在设置中添加手术日期' : '术后第 $day 天';
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.subtitle,
    required this.onRefresh,
  });

  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '腰椎节奏',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '刷新首页',
          icon: const Icon(Icons.refresh_outlined),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('$label：$value/10'),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: '$value',
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
    );
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
                  label: '坐着',
                  value: _formatShortDuration(summary.sittingTotal),
                ),
                _MiniMetricItem(
                  label: '站着',
                  value: _formatShortDuration(summary.standingTotal),
                ),
                _MiniMetricItem(
                  label: '走动',
                  value: _formatShortDuration(summary.walkingTotal),
                ),
                _MiniMetricItem(
                  label: '休息',
                  value: _formatShortDuration(summary.restingTotal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SoftLine(
                label: '最长连续坐着',
                value: _formatShortDuration(summary.longestSitting)),
            _SoftLine(
                label: '最长连续站着',
                value: _formatShortDuration(summary.longestStanding)),
            _SoftLine(label: '姿势切换', value: '${summary.switchCount} 次'),
          ],
        ),
      ),
    );
  }
}

class _TodayRecoveryOverviewCard extends StatelessWidget {
  const _TodayRecoveryOverviewCard({
    required this.overview,
    required this.onEditNote,
  });

  final _HomeTodayOverview overview;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    final rehab = overview.rehabSummary;
    final note = overview.dailyNote;
    final muchWorse = rehab.reactionCount(RehabReaction.muchWorse);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '今日恢复概览',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditNote,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('小结'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MiniMetricGrid(
              items: [
                _MiniMetricItem(label: '康复记录', value: '${rehab.totalCount} 次'),
                _MiniMetricItem(
                  label: '步行总量',
                  value:
                      '${_formatNumber(rehab.totalAmountForActionNamed('步行'))} 分',
                ),
                _MiniMetricItem(label: '明显加重', value: '$muchWorse 次'),
                _MiniMetricItem(
                  label: '今日小结',
                  value: note == null ? '未记录' : note.overallFeeling.label,
                ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 12),
              _SoftLine(label: '腰部不适', value: '${note.backPainScore}/10'),
              _SoftLine(label: '腿部症状', value: '${note.legSymptomScore}/10'),
              _SoftLine(label: '疲劳感', value: '${note.fatigueScore}/10'),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickEntryCard extends StatelessWidget {
  const _QuickEntryCard({
    required this.onOpenCalendar,
    required this.onOpenRehab,
    required this.onOpenReport,
  });

  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenRehab;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                '快捷入口',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            _QuickEntryButton(
              icon: Icons.self_improvement_outlined,
              title: '记录康复动作',
              subtitle: '前往康复页填写完整记录',
              onTap: onOpenRehab,
            ),
            _QuickEntryButton(
              icon: Icons.calendar_month_outlined,
              title: '查看康复日历',
              subtitle: '按日期回看每日状态',
              onTap: onOpenCalendar,
            ),
            _QuickEntryButton(
              icon: Icons.bar_chart_outlined,
              title: '查看康复报告',
              subtitle: '汇总坐站节奏和康复记录',
              onTap: onOpenReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickEntryButton extends StatelessWidget {
  const _QuickEntryButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
  });

  final String label;
  final String value;
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
}

class _PostureStatusCard extends StatelessWidget {
  const _PostureStatusCard({
    required this.session,
    required this.now,
    required this.settings,
    required this.selectedPosture,
    required this.onSelectedPostureChanged,
    required this.onStartOrSwitch,
    required this.onEndCurrent,
  });

  final PostureSession? session;
  final DateTime now;
  final ReminderSettings settings;
  final PostureType selectedPosture;
  final ValueChanged<PostureType?> onSelectedPostureChanged;
  final VoidCallback onStartOrSwitch;
  final VoidCallback onEndCurrent;

  @override
  Widget build(BuildContext context) {
    final current = session;
    final activeType = current?.type;
    final displayType = activeType ?? selectedPosture;
    final durationText =
        current == null ? '00:00' : _formatDuration(current.durationAt(now));
    final statusText =
        current == null ? '尚未开始' : '正在${_postureMenuLabel(current.type)}';
    final statusColor = _postureColor(context, displayType);

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(
            alpha: 0.56,
          ),
      child: Padding(
        padding: const EdgeInsets.all(22),
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
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '当前提醒阈值：${_thresholdText(displayType)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in PostureType.values)
                  ChoiceChip(
                    avatar: Icon(_postureIcon(type), size: 18),
                    label: Text(_postureMenuLabel(type)),
                    selected: selectedPosture == type,
                    onSelected: (_) => onSelectedPostureChanged(type),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onStartOrSwitch,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('开始/切换'),
            ),
            if (current != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onEndCurrent,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('结束当前状态'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _thresholdText(PostureType type) {
    return switch (type) {
      PostureType.sitting => '久坐 ${settings.sittingIntervalMinutes} 分钟',
      PostureType.standing => '久站 ${settings.standingIntervalMinutes} 分钟',
      PostureType.walking || PostureType.resting => '不安排坐站提醒',
    };
  }

  String _postureMenuLabel(PostureType type) {
    return switch (type) {
      PostureType.sitting => '坐着',
      PostureType.standing => '站着',
      PostureType.walking => '走动',
      PostureType.resting => '休息',
    };
  }

  IconData _postureIcon(PostureType type) {
    return switch (type) {
      PostureType.sitting => Icons.event_seat_outlined,
      PostureType.standing => Icons.accessibility_new_outlined,
      PostureType.walking => Icons.directions_walk_outlined,
      PostureType.resting => Icons.bedtime_outlined,
    };
  }

  Color _postureColor(BuildContext context, PostureType type) {
    return switch (type) {
      PostureType.sitting => Theme.of(context).colorScheme.primary,
      PostureType.standing => const Color(0xFF2F7D5C),
      PostureType.walking => const Color(0xFFE09F3E),
      PostureType.resting => const Color(0xFF5B7CFA),
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

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
