class ActivityTrendAxisDay {
  const ActivityTrendAxisDay({
    required this.date,
    required this.hasActivity,
  });

  final DateTime date;
  final bool hasActivity;
}

List<int> buildActivityTrendTickIndexes({
  required List<ActivityTrendAxisDay> days,
  int maxLabels = 5,
}) {
  if (days.isEmpty || maxLabels <= 0) return const [];

  final lastIndex = days.length - 1;
  final activityIndexes = <int>[
    for (var index = 0; index < days.length; index++)
      if (days[index].hasActivity) index,
  ];
  final selected = <int>{0, lastIndex};

  if (activityIndexes.length <= 3) {
    selected.addAll(activityIndexes);
  } else if (days.length >= 30) {
    for (final offset in const [21, 14, 7]) {
      final index = lastIndex - offset;
      if (index >= 0 && index <= lastIndex) {
        selected.add(index);
      }
    }
  } else {
    selected.add((lastIndex / 2).round());
    while (selected.length < maxLabels) {
      final next = _farthestActivityIndex(activityIndexes, selected);
      if (next == null) break;
      selected.add(next);
    }
  }

  return _capSortedIndexes(selected, maxLabels);
}

String formatActivityTrendTickLabel(DateTime date) => date.day.toString();

double activityTrendTickLabelLeft({
  required int index,
  required int dayCount,
  required double availableWidth,
  required double labelWidth,
}) {
  if (availableWidth <= labelWidth || dayCount <= 1) {
    return 0;
  }
  if (index <= 0) {
    return 0;
  }
  if (index >= dayCount - 1) {
    return availableWidth - labelWidth;
  }
  final denominator = dayCount - 1;
  return ((availableWidth * index / denominator) - labelWidth / 2)
      .clamp(0, availableWidth - labelWidth)
      .toDouble();
}

int? _farthestActivityIndex(List<int> activityIndexes, Set<int> selected) {
  int? bestIndex;
  var bestDistance = -1;

  for (final index in activityIndexes) {
    if (selected.contains(index)) continue;
    final nearestDistance = selected
        .map((selectedIndex) => (selectedIndex - index).abs())
        .reduce((left, right) => left < right ? left : right);
    if (nearestDistance > bestDistance) {
      bestDistance = nearestDistance;
      bestIndex = index;
    }
  }

  return bestIndex;
}

List<int> _capSortedIndexes(Set<int> indexes, int maxLabels) {
  final sorted = indexes.toList()..sort();
  if (sorted.length <= maxLabels) return sorted;
  if (maxLabels <= 1) return [sorted.last];

  final capped = <int>{sorted.first, sorted.last};
  for (final index in sorted.skip(1).take(sorted.length - 2)) {
    if (capped.length >= maxLabels) break;
    capped.add(index);
  }
  return capped.toList()..sort();
}
