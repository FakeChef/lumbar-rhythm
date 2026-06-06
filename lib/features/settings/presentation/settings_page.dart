import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../records/application/activity_records_controller.dart';
import '../../reports/application/daily_report_controller.dart';
import '../application/reminder_settings_controller.dart';
import '../data/local_data_repository.dart';
import '../domain/reminder_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _intervalOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(reminderSettingsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '设置',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        settingsState.when(
          loading: () => const _SettingsLoading(),
          error: (error, stackTrace) => _SettingsError(
            onRetry: () => ref.invalidate(reminderSettingsControllerProvider),
          ),
          data: (settings) => _ReminderSettingsSection(
            settings: settings,
            intervalOptions: _intervalOptions,
            onRemindersEnabledChanged: (value) {
              ref
                  .read(reminderSettingsControllerProvider.notifier)
                  .setRemindersEnabled(value);
            },
            onSittingIntervalChanged: (value) {
              if (value == null) return;
              ref
                  .read(reminderSettingsControllerProvider.notifier)
                  .setSittingIntervalMinutes(value);
            },
            onStandingIntervalChanged: (value) {
              if (value == null) return;
              ref
                  .read(reminderSettingsControllerProvider.notifier)
                  .setStandingIntervalMinutes(value);
            },
            onTestReminderPressed: () async {
              final sent = await ref
                  .read(notificationServiceProvider)
                  .showTestReminder();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    sent ? '已发送测试提醒' : '通知没有发出，请在系统设置中允许通知权限',
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 32),
        const ListTile(
          leading: Icon(Icons.storage_outlined),
          title: Text('本地数据'),
          subtitle: Text('姿势记录、症状记录和提醒设置只保存在本地设备。'),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share_outlined),
          title: const Text('备份数据'),
          subtitle: const Text('高级功能：导出本地 JSON，主要用于备份或问题排查。'),
          trailing: IconButton(
            tooltip: '备份数据',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportLocalData(context, ref),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('删除全部本地数据'),
          subtitle: const Text('清除本机保存的记录和提醒设置。'),
          trailing: IconButton(
            tooltip: '删除全部本地数据',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => _confirmDeleteLocalData(context, ref),
          ),
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('隐私说明'),
          subtitle: const Text('查看本 App 的本地优先和数据处理原则。'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showPrivacyDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('免责声明'),
          subtitle: const Text('查看健康提醒工具的医疗边界。'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showDisclaimerDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('关于腰椎节奏'),
          subtitle: const Text('版本 0.1.0+1，永久免费、无广告、无账号。'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAboutDialog(context),
        ),
      ],
    );
  }

  Future<void> _exportLocalData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await ref.read(localDataRepositoryProvider).exportToJson();

    messenger.showSnackBar(
      SnackBar(content: Text('已导出：${file.path}')),
    );
  }

  Future<void> _confirmDeleteLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除全部本地数据？'),
          content: const Text('这会清除本机保存的记录和提醒设置。此操作不会影响云端，因为本 App 不上传数据。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ref.read(localDataRepositoryProvider).deleteAllLocalData();
    await ref.read(notificationServiceProvider).cancelScheduledReminders();
    ref.invalidate(reminderSettingsControllerProvider);
    ref.invalidate(activityRecordsControllerProvider);
    ref.invalidate(dailyReportControllerProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除全部本地数据')),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return const _InfoDialog(
          title: '隐私说明',
          items: [
            '无需注册登录。',
            '不上传健康数据。',
            '姿势记录、症状记录和提醒设置保存在本地设备。',
            '用户可以主动导出数据，也可以删除全部本地数据。',
            '不出售、不共享用户数据，不接入广告追踪 SDK。',
          ],
        );
      },
    );
  }

  void _showDisclaimerDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return const _InfoDialog(
          title: '免责声明',
          items: [
            '本 App 是健康提醒和自我记录工具。',
            '不提供疾病诊断、治疗建议或复发判断。',
            '不替代医生、康复师或其他专业医疗建议。',
            '出现大小便异常、鞍区麻木、进行性下肢无力、术后伤口红肿发热渗液、疼痛突然明显加重等情况，应及时就医。',
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return const _InfoDialog(
          title: '关于腰椎节奏',
          items: [
            '项目名称：腰椎节奏 / Lumbar Rhythm。',
            '版本：0.1.0+1。',
            '永久免费、无广告、无账号、无云端上传。',
            '面向腰突患者、术后恢复人群和久坐办公人群的久坐久站提醒与本地记录工具。',
            '项目坚持本地优先，不接入广告、订阅、第三方追踪或云同步 SDK。',
          ],
        );
      },
    );
  }
}

class _ReminderSettingsSection extends StatelessWidget {
  const _ReminderSettingsSection({
    required this.settings,
    required this.intervalOptions,
    required this.onRemindersEnabledChanged,
    required this.onSittingIntervalChanged,
    required this.onStandingIntervalChanged,
    required this.onTestReminderPressed,
  });

  final ReminderSettings settings;
  final List<int> intervalOptions;
  final ValueChanged<bool> onRemindersEnabledChanged;
  final ValueChanged<int?> onSittingIntervalChanged;
  final ValueChanged<int?> onStandingIntervalChanged;
  final VoidCallback onTestReminderPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          value: settings.remindersEnabled,
          onChanged: onRemindersEnabledChanged,
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('本地提醒'),
          subtitle: const Text('提醒只在本机运行，不上传健康数据。'),
        ),
        const SizedBox(height: 8),
        _IntervalTile(
          icon: Icons.event_seat_outlined,
          title: '久坐提醒间隔',
          value: settings.sittingIntervalMinutes,
          options: intervalOptions,
          onChanged:
              settings.remindersEnabled ? onSittingIntervalChanged : null,
        ),
        _IntervalTile(
          icon: Icons.accessibility_new_outlined,
          title: '久站提醒间隔',
          value: settings.standingIntervalMinutes,
          options: intervalOptions,
          onChanged:
              settings.remindersEnabled ? onStandingIntervalChanged : null,
        ),
        const ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('自动保存'),
          subtitle: Text('以上设置会立即保存到本地数据库。'),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('发送测试提醒'),
          subtitle: const Text('立即发送一条本地通知，用于确认提醒是否可用。'),
          trailing: IconButton(
            tooltip: '发送测试提醒',
            icon: const Icon(Icons.send_outlined),
            onPressed: onTestReminderPressed,
          ),
        ),
      ],
    );
  }
}

class _IntervalTile extends StatelessWidget {
  const _IntervalTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final int value;
  final List<int> options;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text('当前为每 $value 分钟提醒一次'),
      trailing: DropdownButton<int>(
        value: value,
        onChanged: onChanged,
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option,
              child: Text('$option 分钟'),
            ),
        ],
      ),
    );
  }
}

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('- $item'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text('正在读取本地设置'),
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.error_outline),
      title: const Text('设置读取失败'),
      subtitle: const Text('请稍后重试。'),
      trailing: TextButton(
        onPressed: onRetry,
        child: const Text('重试'),
      ),
    );
  }
}
