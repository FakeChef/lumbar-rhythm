import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/local_database.dart';
import '../../actions/domain/action_item.dart';

final localDataRepositoryProvider = Provider<LocalDataRepository>((ref) {
  return LocalDataRepository(ref.watch(localDatabaseProvider));
});

class LocalDataRepository {
  const LocalDataRepository(this._database);

  static const appName = 'Lumbar Rhythm';
  static const appVersion = '0.1.0+1';
  static const backupVersion = 1;
  static const exportSchemaVersion = LocalDatabase.schemaVersion;

  final LocalDatabase _database;

  Future<File> exportToJson() async {
    final payload = await buildBackupPayload();
    final exportedAt = DateTime.parse(
      (payload['metadata'] as Map<String, Object?>)['exportedAt'] as String,
    );
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'lumbar_rhythm_backup_${_dateStamp(exportedAt)}.json';
    final file = File(p.join(directory.path, fileName));

    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<Map<String, Object?>> buildBackupPayload({DateTime? exportedAt}) async {
    final records = await _database.readAllRecords();
    final settings = await _database.readAllSettings();
    final postureSessions = await _database.readAllPostureSessions();
    final rehabActions = await _database.readAllRehabActions();
    final rehabLogs = await _database.readAllRehabLogs();
    final recoveryProfile = await _database.readRecoveryProfile();
    final dailyRecoveryNotes = await _database.readAllDailyRecoveryNotes();
    final recoveryMilestones = await _database.readAllRecoveryMilestones();
    final savedAt = exportedAt ?? DateTime.now();

    return {
      'metadata': {
        'appName': appName,
        'exportedAt': savedAt.toIso8601String(),
        'schemaVersion': exportSchemaVersion,
        'backupVersion': backupVersion,
      },
      'privacy_note':
          'This file was created locally by user action. Lumbar Rhythm does not upload health data.',
      'record_count': records.length,
      'setting_count': settings.length,
      'posture_session_count': postureSessions.length,
      'rehab_action_count': rehabActions.length,
      'rehab_log_count': rehabLogs.length,
      'daily_recovery_note_count': dailyRecoveryNotes.length,
      'recovery_milestone_count': recoveryMilestones.length,
      'settings': settings,
      'records': records,
      'posture_sessions': postureSessions,
      'rehab_actions': rehabActions,
      'activity_master': activityMasterV1.map(_activityToBackupJson).toList(),
      'rehab_logs': rehabLogs,
      'recovery_profile': recoveryProfile,
      'daily_recovery_notes': dailyRecoveryNotes,
      'recovery_milestones': recoveryMilestones,
    };
  }

  Future<void> importFromJsonFile(String path) async {
    final content = await File(path).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Backup root must be a JSON object.');
    }
    await importBackupPayload(decoded);
  }

  Future<void> importBackupPayload(Map<String, Object?> payload) {
    return _database.replaceWithBackupData(payload);
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

  Map<String, Object?> _activityToBackupJson(RehabActivity activity) {
    return {
      'id': activity.id,
      'nameCn': activity.nameCn,
      'category': activity.category,
      'phaseStart': activity.phaseStart,
      'phaseEnd': activity.phaseEnd,
      'defaultUnit': activity.defaultUnit,
      'optionalUnits': activity.optionalUnits,
      'riskLevel': activity.riskLevel,
      'requiresDoctorClearance': activity.requiresDoctorClearance,
      'isDefaultVisible': activity.isDefaultVisible,
      'isCoreActivity': activity.isCoreActivity,
      'sortOrder': activity.sortOrder,
      'patientTip': activity.patientTip,
      'stopRule': activity.stopRule,
    };
  }
}
