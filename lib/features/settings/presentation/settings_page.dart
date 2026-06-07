import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../../core/notifications/notification_service.dart';
import '../../posture/application/posture_session_controller.dart';
import '../../records/application/activity_records_controller.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../reports/application/daily_report_controller.dart';
import '../application/reminder_settings_controller.dart';
import '../data/local_data_repository.dart';
import '../domain/reminder_settings.dart';

const _settingsDisclaimerText = '本报告仅用于个人康复记录回顾，不作为医疗诊断或治疗依据。';

final _settingsTestReminderFeedbackProvider =
    StateProvider.autoDispose<String?>((ref) => null);

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _intervalOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(reminderSettingsControllerProvider);
    final testReminderFeedback =
        ref.watch(_settingsTestReminderFeedbackProvider);
    final testReminderSending = testReminderFeedback == '正在发送测试提醒';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          '设置',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '管理康复资料、坐站提醒、本地数据和隐私说明',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          icon: Icons.person_outline,
          title: '我的康复资料',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('手术日期、手术类型、当前目标'),
              subtitle: const Text('这些内容只用于本地记录展示，可随时跳过或修改。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRecoveryProfileDialog(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 20),
        settingsState.when(
          loading: () => const _SettingsLoading(),
          error: (error, stackTrace) => _SettingsError(
            onRetry: () => ref.invalidate(reminderSettingsControllerProvider),
          ),
          data: (settings) => _SettingsGroup(
            icon: Icons.notifications_active_outlined,
            title: '坐站提醒',
            children: [
              _ReminderSettingsSection(
                settings: settings,
                intervalOptions: _intervalOptions,
                testReminderFeedback: testReminderFeedback,
                testReminderSending: testReminderSending,
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
                onReminderModeChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(reminderSettingsControllerProvider.notifier)
                      .setReminderMode(value);
                },
                onTestReminderPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  ref
                      .read(_settingsTestReminderFeedbackProvider.notifier)
                      .state = '正在发送测试提醒';
                  messenger.showSnackBar(
                    const SnackBar(content: Text('正在发送测试提醒')),
                  );
                  final sent = await ref
                      .read(notificationServiceProvider)
                      .showTestReminder(reminderMode: settings.reminderMode);
                  if (!context.mounted) return;
                  final message = sent ? '已发送测试提醒' : '通知没有发出，请在系统设置中允许通知权限';
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                  ref
                      .read(_settingsTestReminderFeedbackProvider.notifier)
                      .state = message;
                },
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.nightlight_round_outlined),
                title: Text('夜间勿扰'),
                subtitle: Text('当前版本暂未启用，后续会用于减少夜间提醒打扰。'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.visibility_off_outlined),
                title: Text('隐私模式提醒文案'),
                subtitle: Text('该记录一下今天的状态了'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          icon: Icons.folder_open_outlined,
          title: '数据管理',
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.storage_outlined),
              title: Text('本地数据'),
              subtitle: Text('姿势记录、症状记录和提醒设置只保存在本地设备。'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('导出本地数据'),
              subtitle: const Text('导出 JSON 文件，主要用于备份或问题排查。'),
              trailing: IconButton(
                tooltip: '导出本地数据',
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () => _exportLocalData(context, ref),
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.backup_outlined),
              title: Text('本地备份'),
              subtitle: Text('备份文件包含你的本地康复记录，请妥善保存。App 不会自动上传备份文件。'),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('导出本地备份'),
                    onPressed: () => _exportLocalData(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('导入本地备份（高级）'),
                    onPressed: () => _confirmImportLocalBackup(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '备份安全提示：备份文件包含你的本地康复记录，请妥善保存。App 不会自动上传备份文件。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '当前需要粘贴本地 JSON 文件路径。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除全部本地数据'),
              subtitle: const Text('清除本机保存的记录和提醒设置。'),
              trailing: IconButton(
                tooltip: '删除全部本地数据',
                icon: const Icon(Icons.delete_forever_outlined),
                onPressed: () => _confirmDeleteLocalData(context, ref),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          icon: Icons.privacy_tip_outlined,
          title: '隐私与免责声明',
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.verified_user_outlined),
              title: Text('无账号 / 无广告 / 无云端上传'),
              subtitle: Text('核心记录默认保存在本地设备，不接入广告、统计分析或第三方追踪 SDK。'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('隐私说明'),
              subtitle: const Text('查看本 App 的本地优先和数据处理原则。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPrivacyDialog(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: const Text('免责声明'),
              subtitle: const Text(_settingsDisclaimerText),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDisclaimerDialog(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_paused_outlined),
              title: const Text('提醒不准怎么办'),
              subtitle: const Text('查看 Android 本地提醒可能延迟或不显示的常见原因。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showReminderHelpDialog(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: const Text('关于腰椎节奏'),
              subtitle: const Text('版本 0.1.0+1，永久免费、本地优先。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAboutDialog(context),
            ),
          ],
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

  Future<void> _confirmImportLocalBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var backupPath = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        var confirmedOverwrite = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('导入本地备份？'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('导入会覆盖当前本地数据，请先确认已备份。App 不会上传任何数据。'),
                  const SizedBox(height: 8),
                  const Text('当前版本需要粘贴本地 JSON 文件路径，后续会支持文件选择。'),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '本地 JSON 备份文件路径',
                      hintText: '例如：/storage/emulated/0/Download/backup.json',
                    ),
                    onChanged: (value) => backupPath = value,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmedOverwrite,
                    onChanged: (value) {
                      setDialogState(() {
                        confirmedOverwrite = value ?? false;
                      });
                    },
                    title: const Text('我确认导入会覆盖当前本地数据'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: confirmedOverwrite
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('确认导入'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || backupPath.trim().isEmpty) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(localDataRepositoryProvider)
          .importFromJsonFile(backupPath.trim());
      _refreshLocalDataProviders(ref);
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已导入本地备份')));
    } on BackupImportException catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('导入失败，请确认备份文件是有效的 JSON 文件。')),
      );
    }
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
          content: const Text(
            '这会清除本机保存的记录和提醒设置。此操作不会影响其他设备，因为本 App 不上传数据。',
          ),
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
    _refreshLocalDataProviders(ref);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除全部本地数据')),
    );
  }

  void _refreshLocalDataProviders(WidgetRef ref) {
    ref.invalidate(postureSessionControllerProvider);
    ref.invalidate(reminderSettingsControllerProvider);
    ref.invalidate(activityRecordsControllerProvider);
    ref.invalidate(dailyReportControllerProvider);
    ref.read(appDataRefreshProvider.notifier).state++;
  }

  Future<void> _showRecoveryProfileDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(recoveryRepositoryProvider);
    final profile = await repository.loadProfile();
    if (!context.mounted) return;

    DateTime? surgeryDate = profile?.surgeryDate;
    var nickname = profile?.nickname ?? '';
    var surgeryType = profile?.surgeryType ?? '';
    var mainGoal = profile?.mainGoal ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('我的康复资料'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(
                        surgeryDate == null
                            ? '未设置手术日期'
                            : _formatDate(surgeryDate!),
                      ),
                      subtitle: const Text('可跳过，也可用于显示术后第几天。'),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: surgeryDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => surgeryDate = picked);
                          }
                        },
                        child: const Text('选择'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setDialogState(() => surgeryDate = null),
                      child: const Text('跳过手术日期'),
                    ),
                    TextFormField(
                      initialValue: nickname,
                      decoration: const InputDecoration(
                        labelText: '患者昵称（可选）',
                        helperText: '昵称只保存在本地，用于今日页称呼；不要求真实姓名。',
                      ),
                      onChanged: (value) => nickname = value,
                    ),
                    TextFormField(
                      initialValue: surgeryType,
                      decoration: const InputDecoration(labelText: '手术类型（可选）'),
                      onChanged: (value) => surgeryType = value,
                    ),
                    TextFormField(
                      initialValue: mainGoal,
                      decoration: const InputDecoration(labelText: '当前目标（可选）'),
                      onChanged: (value) => mainGoal = value,
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

    await repository.saveProfile(
      surgeryDate: surgeryDate,
      nickname: nickname,
      surgeryType: surgeryType,
      mainGoal: mainGoal,
    );
    ref.invalidate(dailyReportControllerProvider);
    ref.read(appDataRefreshProvider.notifier).state++;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存康复资料')),
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
            '不出售、不共享用户数据，不接入广告、统计分析或第三方追踪 SDK。',
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
            '本 App 是康复提醒和自我记录工具。',
            _settingsDisclaimerText,
            '不替代医生、康复师或其他专业人员的线下指导。',
            '出现大小便异常、鞍区麻木、进行性下肢无力、术后伤口红肿发热渗液、疼痛突然明显加重等情况，应及时就医。',
          ],
        );
      },
    );
  }

  void _showReminderHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return const _InfoDialog(
          title: '提醒不准怎么办',
          items: [
            '确认系统通知权限已允许。',
            '确认手机没有把 App 加入严格省电或后台限制。',
            '部分 Android 手机会为了省电延迟本地提醒，这是系统行为。',
            '本 App 不使用精确闹钟权限，也不依赖云端推送。',
            '如果提醒没有弹出，可先用设置页的测试提醒确认权限状态。',
            '如果测试提醒没有声音，可能需要卸载重装 App，或进入系统通知频道设置打开声音和震动。',
            'Android 通知声音由系统通知频道控制。如果升级后仍无声音，请在系统设置 → 应用 → 腰椎节奏 → 通知中检查声音和震动；必要时可卸载重装后重新允许通知。',
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
            '面向腰突术后康复、久坐办公等场景的久坐久站提醒与本地记录工具。',
            '项目坚持本地优先，不接入广告、订阅、第三方追踪或云同步 SDK。',
          ],
        );
      },
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

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
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReminderSettingsSection extends StatelessWidget {
  const _ReminderSettingsSection({
    required this.settings,
    required this.intervalOptions,
    required this.testReminderFeedback,
    required this.testReminderSending,
    required this.onRemindersEnabledChanged,
    required this.onSittingIntervalChanged,
    required this.onStandingIntervalChanged,
    required this.onReminderModeChanged,
    required this.onTestReminderPressed,
  });

  final ReminderSettings settings;
  final List<int> intervalOptions;
  final String? testReminderFeedback;
  final bool testReminderSending;
  final ValueChanged<bool> onRemindersEnabledChanged;
  final ValueChanged<int?> onSittingIntervalChanged;
  final ValueChanged<int?> onStandingIntervalChanged;
  final ValueChanged<ReminderMode?> onReminderModeChanged;
  final VoidCallback onTestReminderPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.remindersEnabled,
          onChanged: onRemindersEnabledChanged,
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('本地提醒'),
          subtitle: const Text('提醒只在本机运行，不上传健康数据。'),
        ),
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune_outlined),
          title: const Text('提醒方式'),
          subtitle: const Text('默认轻柔通知；需要更明显时可改为震动或响铃。'),
          trailing: DropdownButton<ReminderMode>(
            value: settings.reminderMode,
            onChanged: settings.remindersEnabled ? onReminderModeChanged : null,
            items: [
              for (final mode in ReminderMode.values)
                DropdownMenuItem(
                  value: mode,
                  child: Text(mode.label),
                ),
            ],
          ),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.check_circle_outline),
          title: Text('自动保存'),
          subtitle: Text('以上设置会立即保存到本地数据库。'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('发送测试提醒'),
          subtitle: Text('立即发送一条${settings.reminderMode.label}，用于确认提醒是否可用。'),
          trailing: IconButton(
            tooltip: '发送测试提醒',
            icon: const Icon(Icons.send_outlined),
            onPressed: settings.remindersEnabled && !testReminderSending
                ? onTestReminderPressed
                : null,
          ),
        ),
        if (testReminderFeedback != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 0, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                testReminderFeedback!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
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
      contentPadding: EdgeInsets.zero,
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
    return const _SettingsGroup(
      icon: Icons.notifications_active_outlined,
      title: '坐站提醒',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('正在读取本地设置'),
        ),
      ],
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      icon: Icons.error_outline,
      title: '坐站提醒',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.error_outline),
          title: const Text('设置读取失败'),
          subtitle: const Text('请稍后重试。'),
          trailing: TextButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ),
      ],
    );
  }
}
