import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/reports/presentation/report_chart_axis.dart';

void main() {
  test('week axis with few activity days keeps start today and activity days',
      () {
    final today = DateTime(2026, 6, 9);
    final start = today.subtract(const Duration(days: 6));
    final days = _days(start, 7, activityOffsets: {1, 3, 5});

    final indexes = buildActivityTrendTickIndexes(days: days);

    expect(indexes, [0, 1, 3, 5, 6]);
    expect(_labels(days, indexes), ['3', '4', '6', '8', '9']);
    expect(indexes.length, lessThanOrEqualTo(5));
  });

  test('week axis with many activity days shows representative labels', () {
    final today = DateTime(2026, 6, 9);
    final start = today.subtract(const Duration(days: 6));
    final days = _days(start, 7, activityOffsets: {0, 1, 2, 3, 4, 5, 6});

    final indexes = buildActivityTrendTickIndexes(days: days);

    expect(indexes.first, 0);
    expect(indexes.last, 6);
    expect(indexes.length, lessThanOrEqualTo(5));
    expect(indexes.length, lessThan(7));
    expect(
        _labels(days, indexes).every((label) => !label.contains('/')), isTrue);
  });

  test('month axis with few activity days keeps start today and activity days',
      () {
    final today = DateTime(2026, 6, 9);
    final start = today.subtract(const Duration(days: 29));
    final days = _days(start, 30, activityOffsets: {3, 12, 25});

    final indexes = buildActivityTrendTickIndexes(days: days);

    expect(indexes, [0, 3, 12, 25, 29]);
    expect(_labels(days, indexes), ['11', '14', '23', '5', '9']);
    expect(indexes.length, lessThanOrEqualTo(5));
  });

  test('month axis with many activity days uses weekly lookback labels', () {
    final today = DateTime(2026, 6, 9);
    final start = today.subtract(const Duration(days: 29));
    final days = _days(start, 30, activityOffsets: {0, 4, 8, 12, 16, 20, 24});

    final indexes = buildActivityTrendTickIndexes(days: days);

    expect(indexes, [0, 8, 15, 22, 29]);
    expect(_labels(days, indexes), ['11', '19', '26', '2', '9']);
    expect(indexes.length, lessThanOrEqualTo(5));
  });

  test('tick label only shows day of month', () {
    expect(formatActivityTrendTickLabel(DateTime(2026, 6, 3)), '3');
  });

  test('week axis endpoint labels sit near chart edges', () {
    expect(
      activityTrendTickLabelLeft(
        index: 0,
        dayCount: 7,
        availableWidth: 280,
        labelWidth: 44,
      ),
      0,
    );
    expect(
      activityTrendTickLabelLeft(
        index: 6,
        dayCount: 7,
        availableWidth: 280,
        labelWidth: 44,
      ),
      236,
    );
  });

  test('month axis endpoint labels sit near chart edges', () {
    expect(
      activityTrendTickLabelLeft(
        index: 0,
        dayCount: 30,
        availableWidth: 300,
        labelWidth: 44,
      ),
      0,
    );
    expect(
      activityTrendTickLabelLeft(
        index: 29,
        dayCount: 30,
        availableWidth: 300,
        labelWidth: 44,
      ),
      256,
    );
  });
}

List<ActivityTrendAxisDay> _days(
  DateTime start,
  int count, {
  required Set<int> activityOffsets,
}) {
  return [
    for (var index = 0; index < count; index++)
      ActivityTrendAxisDay(
        date: start.add(Duration(days: index)),
        hasActivity: activityOffsets.contains(index),
      ),
  ];
}

List<String> _labels(List<ActivityTrendAxisDay> days, List<int> indexes) {
  return [
    for (final index in indexes) formatActivityTrendTickLabel(days[index].date),
  ];
}
