import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../posture/application/posture_session_controller.dart';
import '../../posture/domain/posture_session.dart';
import '../../settings/application/reminder_settings_controller.dart';
import '../../settings/domain/reminder_settings.dart';

final _testReminderFeedbackProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(reminderSettingsControllerProvider);
    final postureState = ref.watch(postureSessionControllerProvider);
    final postureNow =
        ref.watch(postureClockProvider).valueOrNull ?? DateTime.now();
    final testReminderFeedback = ref.watch(_testReminderFeedbackProvider);
    final testReminderSending = testReminderFeedback == '正在发送测试提醒…';

    return RefreshIndicator(
      onRefresh: () async {
        _refresh(ref);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '腰椎节奏',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '久坐久站提醒与本地自我记录',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '刷新首页',
                icon: const Icon(Icons.refresh_outlined),
                onPressed: () => _refresh(ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          postureState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取当前姿势'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '当前姿势读取失败',
              onRetry: () => ref.invalidate(postureSessionControllerProvider),
            ),
            data: (session) => _PostureStatusCard(
              session: session,
              now: postureNow,
              onSelect: (type) async {
                await ref
                    .read(postureSessionControllerProvider.notifier)
                    .switchTo(type);
              },
              onEndCurrent: () async {
                await ref
                    .read(postureSessionControllerProvider.notifier)
                    .endCurrent();
              },
            ),
          ),
          const SizedBox(height: 12),
          settingsState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取提醒设置'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '提醒设置读取失败',
              onRetry: () => ref.invalidate(reminderSettingsControllerProvider),
            ),
            data: (settings) => _RhythmCard(
              settings: settings,
              testReminderFeedback: testReminderFeedback,
              testReminderSending: testReminderSending,
              onTestReminderPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                ref.read(_testReminderFeedbackProvider.notifier).state =
                    '正在发送测试提醒…';
                messenger.showSnackBar(
                  const SnackBar(content: Text('正在发送测试提醒…')),
                );
                final sent = await ref
                    .read(notificationServiceProvider)
                    .showTestReminder();
                if (!context.mounted) {
                  return;
                }

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      sent ? '已发送测试提醒' : '通知没有发出，请在系统设置中允许通知权限',
                    ),
                  ),
                );
                ref.read(_testReminderFeedbackProvider.notifier).state =
                    sent ? '已发送测试提醒' : '通知没有发出，请在系统设置中允许通知权限';
              },
            ),
          ),
        ],
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(postureSessionControllerProvider);
    ref.invalidate(reminderSettingsControllerProvider);
  }
}

class _PostureStatusCard extends StatelessWidget {
  const _PostureStatusCard({
    required this.session,
    required this.now,
    required this.onSelect,
    required this.onEndCurrent,
  });

  final PostureSession? session;
  final DateTime now;
  final ValueChanged<PostureType> onSelect;
  final VoidCallback onEndCurrent;

  @override
  Widget build(BuildContext context) {
    final current = session;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    current == null
                        ? '当前姿势：未开始'
                        : '当前姿势：${current.type.shortLabel}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  current == null
                      ? '00:00'
                      : _formatDuration(current.durationAt(now)),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in PostureType.values)
                  ChoiceChip(
                    selected: current?.type == type,
                    label: Text(type.label),
                    onSelected: (_) => onSelect(type),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (current != null) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEndCurrent,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('结束当前状态'),
                ),
              ),
              const SizedBox(height: 4),
            ],
            const Text(
              '切换状态时会自动保存上一段持续时间，并按当前状态安排提醒。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
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

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({
    required this.settings,
    required this.testReminderFeedback,
    required this.testReminderSending,
    required this.onTestReminderPressed,
  });

  final ReminderSettings settings;
  final String? testReminderFeedback;
  final bool testReminderSending;
  final VoidCallback onTestReminderPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    settings.remindersEnabled ? '当前提醒已开启' : '当前提醒已关闭',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('久坐提醒：${settings.sittingIntervalMinutes} 分钟'),
            const SizedBox(height: 4),
            Text('久站提醒：${settings.standingIntervalMinutes} 分钟'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: settings.remindersEnabled && !testReminderSending
                    ? onTestReminderPressed
                    : null,
                icon: const Icon(Icons.send_outlined),
                label: const Text('测试提醒'),
              ),
            ),
            if (testReminderFeedback != null) ...[
              const SizedBox(height: 12),
              Text(
                testReminderFeedback!,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
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
