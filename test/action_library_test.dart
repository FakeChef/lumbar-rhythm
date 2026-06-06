import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';

void main() {
  test('provides a small local action library', () {
    expect(actionLibrary.length, 10);
    expect(actionLibrary.every((item) => item.name.isNotEmpty), isTrue);
    expect(actionLibrary.every((item) => item.defaultUnit.isNotEmpty), isTrue);
    expect(actionLibrary.every((item) => item.guidance.isNotEmpty), isTrue);
  });

  test('keeps action wording out of medical treatment claims', () {
    final combinedText = actionLibrary
        .map((item) => '${item.name} ${item.defaultUnit} ${item.guidance}')
        .join(' ');

    for (final forbidden in ['治疗', '治愈', '预防复发', '诊断', '复发判断']) {
      expect(combinedText, isNot(contains(forbidden)));
    }
  });
}
