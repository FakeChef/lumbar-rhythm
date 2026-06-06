import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../domain/posture_session.dart';

final postureSessionRepositoryProvider = Provider<PostureSessionRepository>(
  (ref) => SqflitePostureSessionRepository(ref.watch(localDatabaseProvider)),
);

abstract class PostureSessionRepository {
  Future<PostureSession?> loadOpenSession();

  Future<PostureSession> switchTo({
    required PostureType type,
    DateTime? now,
  });

  Future<void> endCurrent({DateTime? now});

  Future<List<PostureSession>> loadAll();
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
  }) async {
    final startedAt = now ?? DateTime.now();
    await _database.closeOpenPostureSessions(endedAt: startedAt);
    final id = await _database.insertPostureSession(
      type: type.storageValue,
      startedAt: startedAt,
    );
    return PostureSession(
      id: id,
      type: type,
      startedAt: startedAt,
    );
  }

  @override
  Future<void> endCurrent({DateTime? now}) {
    return _database.closeOpenPostureSessions(endedAt: now ?? DateTime.now());
  }

  @override
  Future<List<PostureSession>> loadAll() async {
    final rows = await _database.readAllPostureSessions();
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
    );
  }
}
