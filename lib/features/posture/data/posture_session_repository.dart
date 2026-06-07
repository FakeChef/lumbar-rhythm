import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../../settings/domain/reminder_settings.dart';
import '../domain/posture_session.dart';

final postureSessionRepositoryProvider = Provider<PostureSessionRepository>(
  (ref) => SqflitePostureSessionRepository(ref.watch(localDatabaseProvider)),
);

abstract class PostureSessionRepository {
  Future<PostureSession?> loadOpenSession();

  Future<PostureSession> switchTo({
    required PostureType type,
    DateTime? now,
    int? sittingThresholdMinutes,
    int? standingThresholdMinutes,
    String endReason = 'user_switch',
    String source = 'manual',
    String? note,
  });

  Future<void> endCurrent({
    DateTime? now,
    int? sittingThresholdMinutes,
    int? standingThresholdMinutes,
    String endReason = 'manual_end',
    String source = 'manual',
    String? note,
  });

  Future<List<PostureSession>> loadAll();

  Future<List<PostureSession>> loadToday({DateTime? now});

  Future<List<PostureSession>> loadRecentDays({
    required int days,
    DateTime? now,
  });

  Future<List<PostureSession>> loadSessionsBetween({
    required DateTime start,
    required DateTime end,
  });
}

class SqflitePostureSessionRepository implements PostureSessionRepository {
  const SqflitePostureSessionRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<PostureSession?> loadOpenSession() async {
    final row = await _database.readOpenPostureSession();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<PostureSession> switchTo({
    required PostureType type,
    DateTime? now,
    int? sittingThresholdMinutes,
    int? standingThresholdMinutes,
    String endReason = 'user_switch',
    String source = 'manual',
    String? note,
  }) async {
    final current = await loadOpenSession();
    if (current?.type == type) {
      return current!;
    }

    final startedAt = now ?? DateTime.now();
    await _database.closeOpenPostureSessions(
      endedAt: startedAt,
      sittingThresholdSeconds: _thresholdSeconds(
        sittingThresholdMinutes,
        ReminderSettings.defaults.sittingIntervalMinutes,
      ),
      standingThresholdSeconds: _thresholdSeconds(
        standingThresholdMinutes,
        ReminderSettings.defaults.standingIntervalMinutes,
      ),
      endReason: endReason,
      source: source,
      note: note,
    );
    final id = await _database.insertPostureSession(
      type: type.storageValue,
      startedAt: startedAt,
      source: source,
    );
    return PostureSession(
      id: id,
      type: type,
      startedAt: startedAt,
    );
  }

  @override
  Future<void> endCurrent({
    DateTime? now,
    int? sittingThresholdMinutes,
    int? standingThresholdMinutes,
    String endReason = 'manual_end',
    String source = 'manual',
    String? note,
  }) {
    return _database.closeOpenPostureSessions(
      endedAt: now ?? DateTime.now(),
      sittingThresholdSeconds: _thresholdSeconds(
        sittingThresholdMinutes,
        ReminderSettings.defaults.sittingIntervalMinutes,
      ),
      standingThresholdSeconds: _thresholdSeconds(
        standingThresholdMinutes,
        ReminderSettings.defaults.standingIntervalMinutes,
      ),
      endReason: endReason,
      source: source,
      note: note,
    );
  }

  @override
  Future<List<PostureSession>> loadAll() async {
    final rows = await _database.readAllPostureSessions();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<PostureSession>> loadToday({DateTime? now}) async {
    final anchor = now ?? DateTime.now();
    final start = DateTime(anchor.year, anchor.month, anchor.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _database.readPostureSessionsStartedBetween(
      start: start,
      end: end,
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<PostureSession>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final todayStart = DateTime(anchor.year, anchor.month, anchor.day);
    final start = todayStart.subtract(Duration(days: days - 1));
    final end = todayStart.add(const Duration(days: 1));
    final rows = await _database.readPostureSessionsStartedBetween(
      start: start,
      end: end,
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<PostureSession>> loadSessionsBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _database.readPostureSessionsStartedBetween(
      start: start,
      end: end,
    );
    return rows.map(_fromRow).toList();
  }

  PostureSession _fromRow(Map<String, Object?> row) {
    final typeValue = row['type'] as String;
    return PostureSession(
      id: row['id'] as int,
      type: PostureType.values.firstWhere(
        (type) => type.storageValue == typeValue,
        orElse: () => PostureType.resting,
      ),
      startedAt: DateTime.parse(row['started_at'] as String),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.parse(row['ended_at'] as String),
      durationSeconds: row['duration_seconds'] as int?,
      thresholdSeconds: row['threshold_seconds'] as int?,
      exceededSeconds: (row['exceeded_seconds'] as int?) ?? 0,
      endReason: row['end_reason'] as String?,
      source: (row['source'] as String?) ?? 'manual',
      note: row['note'] as String?,
    );
  }

  int _thresholdSeconds(int? minutes, int defaultMinutes) {
    return (minutes ?? defaultMinutes) * 60;
  }
}
