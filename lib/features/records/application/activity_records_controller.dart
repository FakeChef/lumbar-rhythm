import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_record_repository.dart';
import '../domain/activity_record.dart';

final activityRecordsControllerProvider =
    AsyncNotifierProvider<ActivityRecordsController, List<ActivityRecord>>(
  ActivityRecordsController.new,
);

class ActivityRecordsController extends AsyncNotifier<List<ActivityRecord>> {
  @override
  Future<List<ActivityRecord>> build() {
    return ref.watch(activityRecordRepositoryProvider).loadToday();
  }

  Future<void> addRecord({
    required ActivityRecordType type,
    String? note,
  }) async {
    final repository = ref.read(activityRecordRepositoryProvider);
    final record = await repository.add(type: type, note: note);
    final current = state.value ?? const [];
    state = AsyncData([
      record,
      for (final existing in current)
        if (existing.id != record.id) existing,
    ]);
  }

  Future<void> deleteRecord(int id) async {
    await ref.read(activityRecordRepositoryProvider).delete(id);
    final current = state.value ?? const [];
    state = AsyncData([
      for (final record in current)
        if (record.id != id) record,
    ]);
  }
}
