import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/local_database.dart';

final localDataRepositoryProvider = Provider<LocalDataRepository>((ref) {
  return LocalDataRepository(ref.watch(localDatabaseProvider));
});

class LocalDataRepository {
  const LocalDataRepository(this._database);

  static const appName = 'Lumbar Rhythm';
  static const appVersion = '0.1.0+1';
  static const exportSchemaVersion = 2;

  final LocalDatabase _database;

  Future<File> exportToJson() async {
    final records = await _database.readAllRecords();
    final settings = await _database.readAllSettings();
    final postureSessions = await _database.readAllPostureSessions();
    final rehabActions = await _database.readAllRehabActions();
    final rehabLogs = await _database.readAllRehabLogs();
    final directory = await getApplicationDocumentsDirectory();
    final exportedAt = DateTime.now();
    final fileName = 'lumbar_rhythm_export_${_dateStamp(exportedAt)}.json';
    final file = File(p.join(directory.path, fileName));

    final payload = {
      'schema_version': exportSchemaVersion,
      'app': appName,
      'app_version': appVersion,
      'exported_at': exportedAt.toIso8601String(),
      'privacy_note':
          'This file was created locally by user action. Lumbar Rhythm does not upload health data.',
      'record_count': records.length,
      'setting_count': settings.length,
      'posture_session_count': postureSessions.length,
      'rehab_action_count': rehabActions.length,
      'rehab_log_count': rehabLogs.length,
      'settings': settings,
      'records': records,
      'posture_sessions': postureSessions,
      'rehab_actions': rehabActions,
      'rehab_logs': rehabLogs,
    };

    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<void> deleteAllLocalData() {
    return _database.deleteAllLocalData();
  }

  String _dateStamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');

    return '$year$month${day}_$hour$minute$second';
  }
}
