import '../../settings/domain/reminder_settings.dart';
import 'posture_session.dart';

enum SittingStandingTimerStatus {
  normal,
  nearReminder,
  overdue,
  overdueWithDiscomfort,
  walking,
  resting,
}

enum SittingStandingTimerTone {
  blue,
  yellow,
  orange,
  redOrange,
  green,
}

class SittingStandingTimerState {
  const SittingStandingTimerState({
    required this.posture,
    required this.elapsed,
    required this.sittingThreshold,
    required this.standingThreshold,
    required this.status,
    required this.tone,
    required this.message,
    required this.suggestion,
    this.threshold,
    this.remaining,
    this.overdueBy,
  });

  final PostureType posture;
  final Duration elapsed;
  final Duration sittingThreshold;
  final Duration standingThreshold;
  final Duration? threshold;
  final Duration? remaining;
  final Duration? overdueBy;
  final SittingStandingTimerStatus status;
  final SittingStandingTimerTone tone;
  final String message;
  final String suggestion;

  String get statusLabel {
    return switch (status) {
      SittingStandingTimerStatus.normal => '节奏正常',
      SittingStandingTimerStatus.nearReminder => '接近提醒',
      SittingStandingTimerStatus.overdue => '已超过建议时间',
      SittingStandingTimerStatus.overdueWithDiscomfort => '建议降低负荷',
      SittingStandingTimerStatus.walking => '正在走动 / 休息中',
      SittingStandingTimerStatus.resting => '正在走动 / 休息中',
    };
  }

  static SittingStandingTimerState calculate({
    required PostureType posture,
    required Duration elapsed,
    ReminderSettings? settings,
    bool hasMarkedDiscomfort = false,
  }) {
    final effectiveSettings = settings ?? ReminderSettings.defaults;
    final sittingThreshold = Duration(
      minutes: effectiveSettings.sittingIntervalMinutes,
    );
    final standingThreshold = Duration(
      minutes: effectiveSettings.standingIntervalMinutes,
    );

    if (posture == PostureType.walking || posture == PostureType.resting) {
      return SittingStandingTimerState(
        posture: posture,
        elapsed: elapsed,
        sittingThreshold: sittingThreshold,
        standingThreshold: standingThreshold,
        threshold: null,
        remaining: null,
        overdueBy: null,
        status: posture == PostureType.walking
            ? SittingStandingTimerStatus.walking
            : SittingStandingTimerStatus.resting,
        tone: SittingStandingTimerTone.green,
        message: posture == PostureType.walking ? '正在走动' : '正在休息',
        suggestion: posture == PostureType.walking
            ? '正在走动，继续按自己的节奏来。'
            : '正在休息，给身体一点缓冲。',
      );
    }

    final threshold =
        posture == PostureType.sitting ? sittingThreshold : standingThreshold;
    final remaining = threshold - elapsed;
    final postureLabel = posture == PostureType.sitting ? '久坐' : '久站';

    if (remaining.isNegative || remaining == Duration.zero) {
      final overdueBy = elapsed - threshold;
      return SittingStandingTimerState(
        posture: posture,
        elapsed: elapsed,
        sittingThreshold: sittingThreshold,
        standingThreshold: standingThreshold,
        threshold: threshold,
        remaining: Duration.zero,
        overdueBy: overdueBy,
        status: hasMarkedDiscomfort
            ? SittingStandingTimerStatus.overdueWithDiscomfort
            : SittingStandingTimerStatus.overdue,
        tone: hasMarkedDiscomfort
            ? SittingStandingTimerTone.redOrange
            : SittingStandingTimerTone.orange,
        message: '已超过建议时间 ${_wholeMinutes(overdueBy)} 分钟',
        suggestion: posture == PostureType.sitting
            ? '起身走两分钟，给身体一个缓冲。'
            : '已经站了一段时间，可以坐下休息一下。',
      );
    }

    if (remaining <= const Duration(minutes: 5)) {
      return SittingStandingTimerState(
        posture: posture,
        elapsed: elapsed,
        sittingThreshold: sittingThreshold,
        standingThreshold: standingThreshold,
        threshold: threshold,
        remaining: remaining,
        overdueBy: null,
        status: SittingStandingTimerStatus.nearReminder,
        tone: SittingStandingTimerTone.yellow,
        message: '距离$postureLabel提醒还有 ${_wholeMinutes(remaining)} 分钟',
        suggestion: posture == PostureType.sitting
            ? '已经坐了一段时间，换个姿势会更友好。'
            : '已经站了一段时间，可以坐下休息一下。',
      );
    }

    return SittingStandingTimerState(
      posture: posture,
      elapsed: elapsed,
      sittingThreshold: sittingThreshold,
      standingThreshold: standingThreshold,
      threshold: threshold,
      remaining: remaining,
      overdueBy: null,
      status: SittingStandingTimerStatus.normal,
      tone: SittingStandingTimerTone.blue,
      message: '距离$postureLabel提醒还有 ${_wholeMinutes(remaining)} 分钟',
      suggestion: posture == PostureType.sitting
          ? '已经坐了一段时间，换个姿势会更友好。'
          : '按当前节奏记录，感觉累了可以坐下休息。',
    );
  }

  static int _wholeMinutes(Duration duration) {
    return duration.inMinutes < 1 ? 1 : duration.inMinutes;
  }
}
