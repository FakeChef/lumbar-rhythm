import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../records/application/activity_records_controller.dart';
import '../../records/domain/activity_record.dart';
import '../../reports/application/daily_report_controller.dart';
import '../../reports/domain/daily_report.dart';
import '../../settings/application/reminder_settings_controller.dart';
import '../../settings/domain/reminder_settings.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(dailyReportControllerProvider);
    final settingsState = ref.watch(reminderSettingsControllerProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reminderSettingsControllerProvider);
        ref.invalidate(activityRecordsControllerProvider);
        ref.invalidate(dailyReportControllerProvider);
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
                onPressed: () {
                  ref.invalidate(reminderSettingsControllerProvider);
                  ref.invalidate(activityRecordsControllerProvider);
                  ref.invalidate(dailyReportControllerProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          settingsState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取提醒设置'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '提醒设置读取失败',
              onRetry: () {
                ref.invalidate(reminderSettingsControllerProvider);
              },
            ),
            data: (settings) => _RhythmCard(
              settings: settings,
              onTestReminderPressed: () async {
                await ref.read(notificationServiceProvider).showTestReminder();
                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已发送测试提醒')),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          reportState.when(
            loading: () => const _HomeLoadingCard(title: '正在读取今日概览'),
            error: (error, stackTrace) => _HomeErrorCard(
              title: '今日概览读取失败',
              onRetry: () {
                ref.invalidate(dailyReportControllerProvider);
              },
            ),
            data: (report) => _TodayOverviewCard(report: report),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.privacy_tip_outlined),
              title: Text('本地优先'),
              subtitle: Text('不登录，不上传健康数据，不接入广告追踪。'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({
    required this.settings,
    required this.onTestReminderPressed,
  });

  final ReminderSettings settings;
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
                onPressed:
                    settings.remindersEnabled ? onTestReminderPressed : null,
                icon: const Icon(Icons.send_outlined),
                label: const Text('测试提醒'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final latest = report.latestRecord;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '今日概览',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text('今日记录：${report.totalCount} 条'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in ActivityRecordType.values)
                  Chip(
                    label: Text('${type.label} ${report.countFor(type)}'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(latest == null ? '最近记录：暂无' : '最近记录：${latest.type.label}'),
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
