import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/records/application/activity_records_controller.dart';
import 'package:lumbar_rhythm/features/records/data/activity_record_repository.dart';
import 'package:lumbar_rhythm/features/records/domain/activity_record.dart';

void main() {
  test('loads today records from repository', () async {
    final repository = _FakeActivityRecordRepository(
      initialRecords: [
        ActivityRecord(
          id: 1,
          type: ActivityRecordType.stretch,
          note: 'walked for five minutes',
          createdAt: DateTime(2026, 6, 5, 9),
        ),
      ],
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    final records =
        await container.read(activityRecordsControllerProvider.future);

    expect(records, hasLength(1));
    expect(records.single.type, ActivityRecordType.stretch);
  });

  test('adds a record and updates state', () async {
    final repository = _FakeActivityRecordRepository();
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    await container.read(activityRecordsControllerProvider.future);
    await container.read(activityRecordsControllerProvider.notifier).addRecord(
          type: ActivityRecordType.symptom,
          note: 'subjective discomfort',
        );

    final records = container.read(activityRecordsControllerProvider).value;

    expect(records, hasLength(1));
    expect(records?.single.type, ActivityRecordType.symptom);
    expect(records?.single.note, 'subjective discomfort');
    expect(repository.addedRecords.single.type, ActivityRecordType.symptom);
  });

  test('deletes a record and updates state', () async {
    final repository = _FakeActivityRecordRepository(
      initialRecords: [
        ActivityRecord(
          id: 1,
          type: ActivityRecordType.sitting,
          createdAt: DateTime(2026, 6, 5, 9),
        ),
        ActivityRecord(
          id: 2,
          type: ActivityRecordType.standing,
          createdAt: DateTime(2026, 6, 5, 10),
        ),
      ],
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    await container.read(activityRecordsControllerProvider.future);
    await container
        .read(activityRecordsControllerProvider.notifier)
        .deleteRecord(1);

    final records = container.read(activityRecordsControllerProvider).value;

    expect(records, hasLength(1));
    expect(records?.single.id, 2);
    expect(repository.deletedIds, [1]);
  });
}

ProviderContainer _createContainer(ActivityRecordRepository repository) {
  return ProviderContainer(
    overrides: [
      activityRecordRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakeActivityRecordRepository implements ActivityRecordRepository {
  _FakeActivityRecordRepository({
    List<ActivityRecord> initialRecords = const [],
  }) : _records = [...initialRecords];

  final List<ActivityRecord> _records;
  final addedRecords = <ActivityRecord>[];
  final deletedIds = <int>[];

  @override
  Future<ActivityRecord> add({
    required ActivityRecordType type,
    String? note,
    DateTime? createdAt,
  }) async {
    final record = ActivityRecord(
      id: _records.length + 1,
      type: type,
      note: note,
      createdAt: createdAt ?? DateTime(2026, 6, 5, 10),
    );
    _records.insert(0, record);
    addedRecords.add(record);
    return record;
  }

  @override
  Future<List<ActivityRecord>> loadToday({DateTime? now}) async {
    return _records;
  }

  @override
  Future<List<ActivityRecord>> loadRecentDays({
    required int days,
    DateTime? now,
  }) async {
    return _records;
  }

  @override
  Future<void> delete(int id) async {
    deletedIds.add(id);
    _records.removeWhere((record) => record.id == id);
  }
}
