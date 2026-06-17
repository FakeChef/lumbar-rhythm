import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final systemTimerHandoffServiceProvider = Provider<SystemTimerHandoffService>(
  (ref) => const SystemTimerHandoffService(),
);

class SystemTimerHandoffResult {
  const SystemTimerHandoffResult({
    required this.success,
    required this.code,
    required this.message,
  });

  final bool success;
  final String code;
  final String message;

  static SystemTimerHandoffResult fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const SystemTimerHandoffResult(
        success: false,
        code: 'system_reminder_failed',
        message: '无法打开系统闹钟或计时器，请手动打开系统时钟设置提醒。',
      );
    }
    return SystemTimerHandoffResult(
      success: map['success'] == true,
      code: map['code']?.toString() ?? 'unknown',
      message: map['message']?.toString() ?? '',
    );
  }
}

class SystemTimerHandoffService {
  const SystemTimerHandoffService();

  static const MethodChannel _channel =
      MethodChannel('lumbar_rhythm/system_timer');

  Future<SystemTimerHandoffResult> startTimer({
    required Duration duration,
    required String message,
  }) async {
    if (duration <= Duration.zero) {
      return const SystemTimerHandoffResult(
        success: false,
        code: 'invalid_duration',
        message: '无法打开系统闹钟或计时器，请手动打开系统时钟设置提醒。',
      );
    }
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'startSystemTimer',
        {
          'durationSeconds': duration.inSeconds,
          'message': message,
        },
      );
      final parsed = SystemTimerHandoffResult.fromMap(result);
      if (!parsed.success && parsed.message.isEmpty) {
        return const SystemTimerHandoffResult(
          success: false,
          code: 'system_reminder_unavailable',
          message: '无法打开系统闹钟或计时器，请手动打开系统时钟设置提醒。',
        );
      }
      return parsed;
    } on PlatformException catch (error) {
      return SystemTimerHandoffResult(
        success: false,
        code: error.code,
        message: '无法打开系统闹钟或计时器，请手动打开系统时钟设置提醒。',
      );
    } catch (_) {
      return const SystemTimerHandoffResult(
        success: false,
        code: 'system_reminder_failed',
        message: '无法打开系统闹钟或计时器，请手动打开系统时钟设置提醒。',
      );
    }
  }
}
