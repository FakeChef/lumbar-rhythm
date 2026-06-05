import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/data/reminder_settings_repository.dart';
import '../features/shell/presentation/main_shell.dart';

class LumbarRhythmApp extends ConsumerStatefulWidget {
  const LumbarRhythmApp({super.key});

  @override
  ConsumerState<LumbarRhythmApp> createState() => _LumbarRhythmAppState();
}

class _LumbarRhythmAppState extends ConsumerState<LumbarRhythmApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_initializeNotifications);
  }

  Future<void> _initializeNotifications() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.initialize();

      final settings =
          await ref.read(reminderSettingsRepositoryProvider).load();
      await notificationService.scheduleNextReminders(
        enabled: settings.remindersEnabled,
        sittingIntervalMinutes: settings.sittingIntervalMinutes,
        standingIntervalMinutes: settings.standingIntervalMinutes,
      );
    } catch (_) {
      // Notification setup should never prevent the app from opening.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '腰椎节奏',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
