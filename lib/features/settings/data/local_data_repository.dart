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

  final LocalDatabase _database;

  Future<File> exportToJson() async {
    final records = await _database.readAllRecords();
    final settings = await _database.readAllSettings();
    final directory = await getApplicationDocumentsDirectory();
    final exportedAt = DateTime.now();
    final fileName = 'lumbar_rhythm_export_${_dateStamp(exportedAt)}.json';
    final file = File(p.join(directory.path, fileName));

    final payload = {
      'app': 'Lumbar Rhythm',
      'exported_at': exportedAt.toIso8601String(),
      'privacy_note': 'This file was created locally by user action.',
      'settings': settings,
      'records': records,
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
