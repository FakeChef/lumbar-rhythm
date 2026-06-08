import 'posture_session.dart';

class PostureSummary {
  const PostureSummary({
    required this.sessions,
    required this.now,
    this.sittingThreshold = const Duration(minutes: 45),
    this.standingThreshold = const Duration(minutes: 30),
  });

  final List<PostureSession> sessions;
  final DateTime now;
  final Duration sittingThreshold;
  final Duration standingThreshold;

  Duration totalFor(PostureType type) {
    return sessions
        .where((session) => session.type == type)
        .fold(Duration.zero, (sum, session) => sum + session.durationAt(now));
  }

  Duration get sittingTotal => totalFor(PostureType.sitting);

  Duration get standingTotal => totalFor(PostureType.standing);

  Duration get walkingTotal => totalFor(PostureType.walking);

  Duration get restingTotal => totalFor(PostureType.resting);

  Duration longestFor(PostureType type) {
    return sessions
        .where((session) => session.type == type)
        .map((session) => session.durationAt(now))
        .fold(Duration.zero, (longest, duration) {
      return duration > longest ? duration : longest;
    });
  }

  Duration get longestSitting => longestFor(PostureType.sitting);

  Duration get longestStanding => longestFor(PostureType.standing);

  Duration get longestWalking => longestFor(PostureType.walking);

  int get switchCount => sessions.isEmpty ? 0 : sessions.length - 1;

  int get sittingBreakCount {
    final ordered = [...sessions]
      ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
    var count = 0;
    for (var index = 1; index < ordered.length; index++) {
      if (ordered[index - 1].type == PostureType.sitting &&
          ordered[index].type == PostureType.walking) {
        count++;
      }
    }
    return count;
  }

  int get sittingOverThresholdCount {
    return sessions
        .where((session) => session.type == PostureType.sitting)
        .where((session) =>
            session.exceededSeconds > 0 ||
            session.durationAt(now) > sittingThreshold)
        .length;
  }

  int get standingOverThresholdCount {
    return sessions
        .where((session) => session.type == PostureType.standing)
        .where((session) =>
            session.exceededSeconds > 0 ||
            session.durationAt(now) > standingThreshold)
        .length;
  }

  int get walkingOverThresholdCount {
    return sessions
        .where((session) => session.type == PostureType.walking)
        .where((session) => session.exceededSeconds > 0)
        .length;
  }

  int get rhythmReminderCount {
    return sittingOverThresholdCount + walkingOverThresholdCount;
  }

  int get stopCount {
    return sessions
        .where((session) => session.endReason == 'manual_end')
        .length;
  }

  List<PostureDaySummary> recentDaySummaries({required int days}) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    return [
      for (var index = 0; index < days; index++)
        _daySummary(start.add(Duration(days: index))),
    ];
  }

  PostureDaySummary _daySummary(DateTime day) {
    final nextDay = day.add(const Duration(days: 1));
    final daySessions = sessions.where((session) {
      final startedAt = session.startedAt;
      return !startedAt.isBefore(day) && startedAt.isBefore(nextDay);
    }).toList();
    final summary = PostureSummary(sessions: daySessions, now: now);
    return PostureDaySummary(
      day: day,
      sitting: summary.sittingTotal,
      standing: summary.standingTotal,
      walking: summary.walkingTotal,
      resting: summary.restingTotal,
    );
  }
}

class PostureDaySummary {
  const PostureDaySummary({
    required this.day,
    required this.sitting,
    required this.standing,
    required this.walking,
    required this.resting,
  });

  final DateTime day;
  final Duration sitting;
  final Duration standing;
  final Duration walking;
  final Duration resting;
}
