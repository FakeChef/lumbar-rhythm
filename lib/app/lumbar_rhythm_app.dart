import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_service.dart';
import '../core/theme/app_theme.dart';
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
    Future.microtask(() {
      ref.read(notificationServiceProvider).initialize();
    });
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
