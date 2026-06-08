import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../features/posture/data/posture_session_repository.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeNotifications());
    });
  }

  Future<void> _initializeNotifications() async {
    final notificationService = ref.read(notificationServiceProvider);
    try {
      await notificationService.initialize();

      final settings =
          await ref.read(reminderSettingsRepositoryProvider).load();
      if (settings.remindersEnabled) {
        await notificationService.requestPermissions();
      }
      final openSession =
          await ref.read(postureSessionRepositoryProvider).loadOpenSession();
      await notificationService.scheduleNextReminders(
        enabled: settings.remindersEnabled,
        sittingIntervalMinutes: settings.sittingIntervalMinutes,
        standingIntervalMinutes: settings.standingIntervalMinutes,
        walkingIntervalMinutes: settings.walkingIntervalMinutes,
        reminderMode: settings.reminderMode,
        currentPosture: openSession?.type,
        currentSessionStartedAt: openSession?.startedAt,
      );
    } catch (error) {
      notificationService.recordError(error);
      // Notification setup should never prevent the app from opening.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '腰椎节奏',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
