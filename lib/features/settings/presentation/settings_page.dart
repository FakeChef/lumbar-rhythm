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

const _settingsDisclaimerText = '本报告仅用于个人康复记录回顾，不作为专业判断依据。';

final _settingsTestReminderFeedbackProvider =
    StateProvider.autoDispose<String?>((ref) => null);

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _intervalOptions = [15, 30, 45, 60, 90, 120];
  static const _walkingIntervalOptions = [3, 5, 10, 15, 20, 30];
  static const _daytimePhaseOptions = [3, 5, 10, 15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(reminderSettingsControllerProvider);
    final reminderDebugState = ref.watch(reminderDebugStateProvider);
    final testReminderFeedback =
        ref.watch(_settingsTestReminderFeedbackProvider);
    final testReminderSending = testReminderFeedback?.startsWith('正在') ?? false;

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
              title: const Text('昵称与手术日期'),
              subtitle: const Text('患者昵称可选，手术日期为必填，用于显示术后天数。'),
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
                walkingIntervalOptions: _walkingIntervalOptions,
                daytimePhaseOptions: _daytimePhaseOptions,
                debugState: reminderDebugState,
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
                onWalkingIntervalChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(reminderSettingsControllerProvider.notifier)
                      .setWalkingIntervalMinutes(value);
                },
                onDaytimeLoopEnabledChanged: (value) {
                  ref
                      .read(reminderSettingsControllerProvider.notifier)
                      .setDaytimeLoopEnabled(value);
                },
                onDaytimeStartChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(reminderSettingsControllerProvider.notifier)
                      .setDaytimeStartMinutes(value);
                },
                onDaytimeEndChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(reminderSettingsControllerProvider.notifier)
                      .setDaytimeEndMinutes(value);
                },
                onDaytimeSittingChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(reminderSettingsControllerProvider.notifier)
                      .setDaytimeSittingMinutes(value);
                },
                onDaytimeWalkingChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(reminderSettingsControllerProvider.notifier)
                      .setDaytimeWalkingMinutes(value);
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
                      .state = '正在发送立即测试提醒';
                  messenger.showSnackBar(
                    const SnackBar(content: Text('正在发送立即测试提醒')),
                  );
                  final sent = await ref
                      .read(notificationServiceProvider)
                      .showReminderNow(
                        mode: settings.reminderMode,
                        title: '腰椎节奏提醒测试',
                        body: '本地通知已可用。后续提醒会按你的设置安排。',
                        markAsImmediateTest: true,
                      );
                  if (!context.mounted) return;
                  final message = sent ? '已立即发送测试提醒' : '立即测试提醒没有发出';
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                  ref
                      .read(_settingsTestReminderFeedbackProvider.notifier)
                      .state = message;
                },
                onForegroundTestPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  ref
                      .read(_settingsTestReminderFeedbackProvider.notifier)
                      .state = '正在安排 10 秒前台测试';
                  final scheduled = await ref
                      .read(notificationServiceProvider)
                      .scheduleForegroundTimerTestReminder(
                        reminderMode: settings.reminderMode,
                        onFired: (shown) {
                          if (!context.mounted) return;
                          final firedMessage = shown
                              ? '10 秒前台测试提醒已触发'
                              : '10 秒前台测试触发失败，请检查系统通知设置';
                          messenger.showSnackBar(
                            SnackBar(content: Text(firedMessage)),
                          );
                          ref
                              .read(
                                _settingsTestReminderFeedbackProvider.notifier,
                              )
                              .state = firedMessage;
                        },
                      );
                  if (!context.mounted) return;
                  final message = scheduled ? '已安排 10 秒前台测试' : '10 秒前台测试没有安排成功';
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                  ref
                      .read(_settingsTestReminderFeedbackProvider.notifier)
                      .state = message;
                },
                onOneMinuteTestPressed: () async {
                  await _runScheduleDiagnostic(
                    context: context,
                    ref: ref,
                    settings: settings,
                    mode: ReminderScheduleDiagnosticMode.inexactAllowWhileIdle,
                  );
                },
                onExactOneMinuteTestPressed: () async {
                  await _runScheduleDiagnostic(
                    context: context,
                    ref: ref,
                    settings: settings,
                    mode: ReminderScheduleDiagnosticMode.exactAllowWhileIdle,
                  );
                },
                onAlarmClockOneMinuteTestPressed: () async {
                  await _runScheduleDiagnostic(
                    context: context,
                    ref: ref,
                    settings: settings,
                    mode: ReminderScheduleDiagnosticMode.alarmClock,
                  );
                },
                onPendingPressed: () async {
                  final debug = await ref
                      .read(notificationServiceProvider)
                      .refreshPendingScheduledNotifications();
                  if (!context.mounted) return;
                  final message =
                      '当前待触发提醒：${debug.pendingNotificationCount ?? 0} 个';
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(message)));
                  ref
                      .read(_settingsTestReminderFeedbackProvider.notifier)
                      .state = message;
                },
                onDiagnosticsPressed: () {
                  _showReminderDiagnosticsDialog(context, ref, settings);
                },
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
                      subtitle: const Text('必填，用于今日页显示术后第几天。'),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: surgeryDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            locale: const Locale('zh', 'CN'),
                          );
                          if (picked != null) {
                            setDialogState(() => surgeryDate = picked);
                          }
                        },
                        child: const Text('选择'),
                      ),
                    ),
                    TextFormField(
                      initialValue: nickname,
                      decoration: const InputDecoration(
                        labelText: '患者昵称（可选）',
                        helperText: '昵称只保存在本地，用于今日页称呼；不要求真实姓名。',
                      ),
                      onChanged: (value) => nickname = value,
                    ),
                    const SizedBox(height: 12),
                    const _RecoveryPhaseExplanationTile(),
                    if (surgeryDate == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '请先选择手术日期。',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                        ),
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
                  onPressed: surgeryDate == null
                      ? null
                      : () => Navigator.of(context).pop(true),
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
      surgeryType: profile?.surgeryType,
      mainGoal: profile?.mainGoal,
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

class _RecoveryPhaseExplanationTile extends StatelessWidget {
  const _RecoveryPhaseExplanationTile();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            '康复阶段说明',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          subtitle: const Text('了解术后记录节奏的分期逻辑'),
          children: const [
            _RecoveryPhaseParagraph(
              text:
                  '本康复计划基于现代运动医学的“组织愈合生理周期（Tissue Healing Phases）”科学构建。人体修复并非线性过程，而是经历炎症消退、组织增生、胶原纤维重塑到功能成熟的四个生物学阶段。',
            ),
            _RecoveryPhaseParagraph(
              text: '我们将其科学划分为四个阶段，目的是让您的康复节奏与身体的修复节奏高度同步：',
            ),
            _RecoveryPhaseParagraph(
              title: '第1阶段（0-4周）',
              text: '急性愈合与神经唤醒。聚焦炎症期管理，通过神经唤醒保护受损组织，防止早期过度负荷导致的二次损伤。',
            ),
            _RecoveryPhaseParagraph(
              title: '第2阶段（4-8周）',
              text: '运动控制与动态稳定。针对组织增生期，重点在于通过科学运动，将零散的纤维转化为有序的受控力量。',
            ),
            _RecoveryPhaseParagraph(
              title: '第3阶段（8-12周）',
              text: '功能性负荷进阶。对应组织重塑成熟期，通过功能性负荷训练，提升胶原纤维的强度与韧性，重建关节承重能力。',
            ),
            _RecoveryPhaseParagraph(
              title: '第4阶段（12周后）',
              text: '高负荷恢复。针对组织功能成熟期，由受控训练全面过渡至自主运动，助您回归正常生活与运动状态。',
            ),
            _RecoveryPhaseParagraph(
              text:
                  '这套分期体系不仅是为了确保生理修复的安全性，更是在每一个生理窗口期提供对应的心理与行动支持，帮您稳步找回身体的掌控权。',
            ),
            _RecoveryPhaseParagraph(
              isFootnote: true,
              text: '以上阶段说明仅用于帮助理解记录节奏，不作为医疗诊断或个人康复处方。',
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryPhaseParagraph extends StatelessWidget {
  const _RecoveryPhaseParagraph({
    required this.text,
    this.title,
    this.isFootnote = false,
  });

  final String? title;
  final String text;
  final bool isFootnote;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final color =
        isFootnote ? Theme.of(context).colorScheme.onSurfaceVariant : null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
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
    required this.walkingIntervalOptions,
    required this.daytimePhaseOptions,
    required this.debugState,
    required this.testReminderFeedback,
    required this.testReminderSending,
    required this.onRemindersEnabledChanged,
    required this.onSittingIntervalChanged,
    required this.onWalkingIntervalChanged,
    required this.onDaytimeLoopEnabledChanged,
    required this.onDaytimeStartChanged,
    required this.onDaytimeEndChanged,
    required this.onDaytimeSittingChanged,
    required this.onDaytimeWalkingChanged,
    required this.onReminderModeChanged,
    required this.onTestReminderPressed,
    required this.onForegroundTestPressed,
    required this.onOneMinuteTestPressed,
    required this.onExactOneMinuteTestPressed,
    required this.onAlarmClockOneMinuteTestPressed,
    required this.onPendingPressed,
    required this.onDiagnosticsPressed,
  });

  final ReminderSettings settings;
  final List<int> intervalOptions;
  final List<int> walkingIntervalOptions;
  final List<int> daytimePhaseOptions;
  final ReminderDebugState debugState;
  final String? testReminderFeedback;
  final bool testReminderSending;
  final ValueChanged<bool> onRemindersEnabledChanged;
  final ValueChanged<int?> onSittingIntervalChanged;
  final ValueChanged<int?> onWalkingIntervalChanged;
  final ValueChanged<bool> onDaytimeLoopEnabledChanged;
  final ValueChanged<int?> onDaytimeStartChanged;
  final ValueChanged<int?> onDaytimeEndChanged;
  final ValueChanged<int?> onDaytimeSittingChanged;
  final ValueChanged<int?> onDaytimeWalkingChanged;
  final ValueChanged<ReminderMode?> onReminderModeChanged;
  final VoidCallback onTestReminderPressed;
  final VoidCallback onForegroundTestPressed;
  final VoidCallback onOneMinuteTestPressed;
  final VoidCallback onExactOneMinuteTestPressed;
  final VoidCallback onAlarmClockOneMinuteTestPressed;
  final VoidCallback onPendingPressed;
  final VoidCallback onDiagnosticsPressed;

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
          title: '走动提醒间隔',
          value: settings.walkingIntervalMinutes,
          options: walkingIntervalOptions,
          onChanged:
              settings.remindersEnabled ? onWalkingIntervalChanged : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.daytimeLoopEnabled,
          onChanged: onDaytimeLoopEnabledChanged,
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: const Text('白天节奏'),
          subtitle:
              const Text('白天节奏会在指定时间段内循环提醒：坐一段时间后走动，走动一段时间后坐下休息。你可以随时停止。'),
        ),
        _ClockMinuteTile(
          icon: Icons.play_circle_outline,
          title: '开始时间',
          value: settings.daytimeStartMinutes,
          options: const [8 * 60, 9 * 60, 10 * 60],
          onChanged: settings.daytimeLoopEnabled ? onDaytimeStartChanged : null,
        ),
        _ClockMinuteTile(
          icon: Icons.stop_circle_outlined,
          title: '结束时间',
          value: settings.daytimeEndMinutes,
          options: const [17 * 60, 18 * 60, 19 * 60],
          onChanged: settings.daytimeLoopEnabled ? onDaytimeEndChanged : null,
        ),
        _IntervalTile(
          icon: Icons.event_seat_outlined,
          title: '坐姿阶段',
          value: settings.daytimeSittingMinutes,
          options: daytimePhaseOptions,
          onChanged:
              settings.daytimeLoopEnabled ? onDaytimeSittingChanged : null,
        ),
        _IntervalTile(
          icon: Icons.directions_walk_outlined,
          title: '走动阶段',
          value: settings.daytimeWalkingMinutes,
          options: daytimePhaseOptions,
          onChanged:
              settings.daytimeLoopEnabled ? onDaytimeWalkingChanged : null,
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
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('提醒诊断'),
          subtitle: const Text('检查通知权限、通道、立即提醒和 10 秒定时提醒。'),
          trailing: IconButton(
            tooltip: '提醒诊断',
            icon: const Icon(Icons.chevron_right),
            onPressed: onDiagnosticsPressed,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('立即测试提醒'),
          subtitle: Text('立即发送一条${settings.reminderMode.label}，用于确认通知通道。'),
          trailing: IconButton(
            tooltip: '立即测试提醒',
            icon: const Icon(Icons.send_outlined),
            onPressed: settings.remindersEnabled && !testReminderSending
                ? onTestReminderPressed
                : null,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timer_10_outlined),
          title: const Text('10 秒前台测试'),
          subtitle: Text(
              '验证 App 打开时的主提醒路径：10 秒后由前台计时器发送一条${settings.reminderMode.label}。'),
          trailing: IconButton(
            tooltip: '10 秒前台测试',
            icon: const Icon(Icons.play_arrow_outlined),
            onPressed: settings.remindersEnabled && !testReminderSending
                ? onForegroundTestPressed
                : null,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('1 分钟定时测试：inexactAllowWhileIdle'),
          subtitle: const Text('Android 后台定时辅助路径，可能受系统调度影响。'),
          trailing: IconButton(
            tooltip: '1 分钟定时测试：inexactAllowWhileIdle',
            icon: const Icon(Icons.timer_outlined),
            onPressed: settings.remindersEnabled && !testReminderSending
                ? onOneMinuteTestPressed
                : null,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_send_outlined),
          title: const Text('1 分钟定时测试：exactAllowWhileIdle'),
          subtitle: const Text('仅用于排查；若系统或权限不支持，会显示错误。'),
          trailing: IconButton(
            tooltip: '1 分钟定时测试：exactAllowWhileIdle',
            icon: const Icon(Icons.timer_outlined),
            onPressed: settings.remindersEnabled && !testReminderSending
                ? onExactOneMinuteTestPressed
                : null,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alarm_outlined),
          title: const Text('1 分钟定时测试：alarmClock'),
          subtitle: const Text('仅用于排查；不会把 App 默认改成闹钟应用。'),
          trailing: IconButton(
            tooltip: '1 分钟定时测试：alarmClock',
            icon: const Icon(Icons.timer_outlined),
            onPressed: settings.remindersEnabled && !testReminderSending
                ? onAlarmClockOneMinuteTestPressed
                : null,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.fact_check_outlined),
          title: const Text('查看待触发提醒'),
          subtitle: Text(
            '当前待触发提醒：${debugState.pendingNotificationCount ?? 0} 个',
          ),
          trailing: IconButton(
            tooltip: '查看待触发提醒',
            icon: const Icon(Icons.refresh_outlined),
            onPressed: onPendingPressed,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(56, 0, 0, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '如果定时测试没有弹出，但 pending 消失，说明系统已处理该定时提醒，但本机可能未展示；正式提醒会以前台 Timer 为主。',
            ),
          ),
        ),
        _ReminderDebugPanel(debugState: debugState),
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

class _ReminderDebugPanel extends StatelessWidget {
  const _ReminderDebugPanel({required this.debugState});

  final ReminderDebugState debugState;

  @override
  Widget build(BuildContext context) {
    final lines = [
      'notificationId: ${debugState.lastNotificationId ?? '-'}',
      'reminderMode: ${debugState.lastReminderMode?.label ?? '-'}',
      'channelId: ${debugState.lastChannelId ?? '-'}',
      'foregroundWatcherActive: ${debugState.foregroundWatcherActive ?? '-'}',
      'foregroundDueAt: ${_formatClockMinuteFromDate(debugState.foregroundDueAt)}',
      'foregroundFiredAt: ${_formatClockMinuteFromDate(debugState.foregroundFiredAt)}',
      'lifecycleCatchupFiredAt: ${_formatClockMinuteFromDate(debugState.lifecycleCatchupFiredAt)}',
      'scheduledAt: ${_formatClockMinuteFromDate(debugState.lastLocalScheduleRequestedAt)}',
      'dueAt: ${_formatClockMinuteFromDate(debugState.lastLocalScheduleDueAt)}',
      'lastPostureReminderDueAt: ${_formatClockMinuteFromDate(debugState.lastPostureReminderDueAt)}',
      'lastPostureReminderTriggeredBy: ${debugState.lastPostureReminderTriggeredBy ?? '-'}',
      'postureType: ${debugState.lastPostureReminderType?.name ?? '-'}',
      'postureSessionStartedAt: ${_formatClockMinuteFromDate(debugState.lastPostureReminderSessionStartedAt)}',
      'posturePending: ${debugState.lastPostureReminderPending ?? '-'}',
      'scheduledMode: ${debugState.lastScheduledModeUsed ?? '-'}',
      'scheduleResult: ${debugState.lastScheduleModeResult ?? '-'}',
      'pendingBefore: ${debugState.scheduledPendingBefore ?? '-'}',
      'pendingAfter: ${debugState.scheduledPendingAfter ?? '-'}',
      'pending: ${debugState.pendingNotificationCount ?? 0} ${debugState.pendingNotificationIds}',
      if (debugState.lastErrorMessage != null)
        'error: ${debugState.lastErrorMessage}',
      if (debugState.lastHybridReminderError != null)
        'hybridError: ${debugState.lastHybridReminderError}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 0, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          lines.join('\n'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

Future<void> _showReminderDiagnosticsDialog(
  BuildContext context,
  WidgetRef ref,
  ReminderSettings settings,
) async {
  await ref.read(notificationServiceProvider).refreshReminderDiagnostics();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _ReminderDiagnosticsDialog(settings: settings),
  );
}

class _ReminderDiagnosticsDialog extends ConsumerWidget {
  const _ReminderDiagnosticsDialog({required this.settings});

  final ReminderSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugState = ref.watch(reminderDebugStateProvider);
    final channelId = channelIdForReminderMode(settings.reminderMode);
    return AlertDialog(
      title: const Text('提醒诊断'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DiagnosticLine(
                label: '当前提醒模式', value: settings.reminderMode.label),
            _DiagnosticLine(label: '当前 channel id', value: channelId),
            _DiagnosticLine(
              label: '通知权限状态',
              value: _formatDiagnosticBool(
                debugState.notificationsEnabled,
                trueText: '已允许',
                falseText: '未允许',
              ),
            ),
            _DiagnosticLine(
              label: '精确提醒状态',
              value: _formatDiagnosticBool(
                debugState.exactNotificationsAvailable,
                trueText: '可用',
                falseText: '不可用',
              ),
            ),
            const SizedBox(height: 8),
            const Text('最近一次真实坐站提醒：'),
            _DiagnosticLine(
              label: 'postureType',
              value: debugState.lastPostureReminderType?.name ?? '-',
            ),
            _DiagnosticLine(
              label: 'delay',
              value: _formatDiagnosticDelay(debugState),
            ),
            _DiagnosticLine(
              label: 'scheduledAt',
              value: _formatClockMinuteFromDate(
                debugState.lastLocalScheduleRequestedAt,
              ),
            ),
            _DiagnosticLine(
              label: 'dueAt',
              value: _formatClockMinuteFromDate(
                debugState.lastLocalScheduleDueAt,
              ),
            ),
            _DiagnosticLine(
              label: 'channel id',
              value: debugState.lastChannelId ?? '-',
            ),
            _DiagnosticLine(
              label: 'pending',
              value:
                  '${debugState.lastPostureReminderPending ?? '-'} / ${debugState.pendingNotificationCount ?? 0} ${debugState.pendingNotificationIds}',
            ),
            const SizedBox(height: 12),
            const Text(
              '部分安卓系统可能延迟后台提醒，打开 App 时会自动补发到期提醒。若测试提醒没有声音，请检查系统设置中的通知权限、通知频道声音、勿扰模式和电池限制。',
            ),
            const SizedBox(height: 16),
            _DiagnosticButton(
              icon: Icons.verified_outlined,
              label: '检查并请求通知权限',
              onPressed: () => _requestDiagnosticPermission(context, ref),
            ),
            _DiagnosticButton(
              icon: Icons.send_outlined,
              label: '发送立即测试提醒',
              onPressed: () => _runDiagnosticAction(
                context: context,
                ref: ref,
                action: () => ref
                    .read(notificationServiceProvider)
                    .showImmediateDiagnosticReminder(
                      reminderMode: settings.reminderMode,
                    ),
                successMessage: '已发送立即测试提醒',
              ),
            ),
            _DiagnosticButton(
              icon: Icons.timer_10_outlined,
              label: '10 秒后测试提醒',
              onPressed: () => _runDiagnosticAction(
                context: context,
                ref: ref,
                action: () => ref
                    .read(notificationServiceProvider)
                    .scheduleTenSecondDiagnosticReminder(
                      reminderMode: settings.reminderMode,
                    ),
                successMessage: '已安排 10 秒后提醒',
              ),
            ),
            _DiagnosticButton(
              icon: Icons.event_seat_outlined,
              label: '1 分钟真实久坐提醒测试',
              onPressed: () => _runDiagnosticAction(
                context: context,
                ref: ref,
                action: () async {
                  await ref
                      .read(postureSessionControllerProvider.notifier)
                      .startTodaySittingChainTest();
                  return true;
                },
                successMessage: '已开启 1 分钟真实久坐提醒测试',
              ),
            ),
            _DiagnosticButton(
              icon: Icons.vibration_outlined,
              label: '测试震动提醒',
              onPressed: () => _runDiagnosticAction(
                context: context,
                ref: ref,
                action: () => ref
                    .read(notificationServiceProvider)
                    .showVibrationDiagnosticReminder(),
                successMessage: '已发送立即测试提醒',
              ),
            ),
            _DiagnosticButton(
              icon: Icons.notifications_active_outlined,
              label: '测试响铃提醒',
              onPressed: () => _runDiagnosticAction(
                context: context,
                ref: ref,
                action: () => ref
                    .read(notificationServiceProvider)
                    .showAlarmDiagnosticReminder(),
                successMessage: '已发送立即测试提醒',
              ),
            ),
            if (debugState.lastErrorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                '错误：${debugState.lastErrorMessage}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
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

class _DiagnosticLine extends StatelessWidget {
  const _DiagnosticLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label：$value'),
    );
  }
}

class _DiagnosticButton extends StatelessWidget {
  const _DiagnosticButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}

String _formatDiagnosticBool(
  bool? value, {
  required String trueText,
  required String falseText,
}) {
  if (value == null) {
    return '未知';
  }
  return value ? trueText : falseText;
}

String _formatDiagnosticDelay(ReminderDebugState debugState) {
  final scheduledAt = debugState.lastLocalScheduleRequestedAt;
  final dueAt = debugState.lastLocalScheduleDueAt;
  if (scheduledAt == null || dueAt == null) {
    return '-';
  }
  final seconds = dueAt.difference(scheduledAt).inSeconds;
  if (seconds >= 60 && seconds % 60 == 0) {
    return '${seconds ~/ 60} minute';
  }
  return '$seconds seconds';
}

Future<void> _requestDiagnosticPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final granted =
        await ref.read(notificationServiceProvider).requestPermissions();
    await ref.read(notificationServiceProvider).refreshReminderDiagnostics();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(granted ? '通知权限已允许' : '通知权限未允许，请先开启'),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('检查通知权限失败，请稍后重试。')),
    );
  }
}

Future<void> _runDiagnosticAction({
  required BuildContext context,
  required WidgetRef ref,
  required Future<bool> Function() action,
  required String successMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok = await action();
    await ref.read(notificationServiceProvider).refreshReminderDiagnostics();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? successMessage : '通知权限未允许，请先开启'),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('提醒测试失败，请检查系统通知设置。')),
    );
  }
}

Future<void> _runScheduleDiagnostic({
  required BuildContext context,
  required WidgetRef ref,
  required ReminderSettings settings,
  required ReminderScheduleDiagnosticMode mode,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  ref.read(_settingsTestReminderFeedbackProvider.notifier).state =
      '正在安排 1 分钟定时测试：${mode.label}';
  final scheduled = await ref
      .read(notificationServiceProvider)
      .scheduleOneMinuteSittingTestReminder(
        reminderMode: settings.reminderMode,
        diagnosticMode: mode,
      );
  if (!context.mounted) return;
  final debug = ref.read(reminderDebugStateProvider);
  final dueAt = debug.lastLocalScheduleDueAt;
  final result = debug.lastScheduleModeResult ?? '已请求安排，等待 pending 确认。';
  final message = scheduled
      ? '已安排 1 分钟定时测试：${mode.label}，预计 ${_formatClockMinuteFromDate(dueAt)} 触发。$result'
      : '1 分钟定时测试：${mode.label} 没有安排成功';
  messenger.showSnackBar(SnackBar(content: Text(message)));
  ref.read(_settingsTestReminderFeedbackProvider.notifier).state = message;
}

class _ClockMinuteTile extends StatelessWidget {
  const _ClockMinuteTile({
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
      subtitle: Text('当前为 ${_formatClockMinute(value)}'),
      trailing: DropdownButton<int>(
        value: value,
        onChanged: onChanged,
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option,
              child: Text(_formatClockMinute(option)),
            ),
        ],
      ),
    );
  }
}

String _formatClockMinute(int value) {
  final hour = value ~/ 60;
  final minute = value.remainder(60);
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _formatClockMinuteFromDate(DateTime? value) {
  if (value == null) {
    return '-';
  }
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
