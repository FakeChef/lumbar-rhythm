import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';

void main() {
  test('provides a small local action library', () {
    expect(actionLibrary.length, greaterThanOrEqualTo(4));
    expect(actionLibrary.every((item) => item.name.isNotEmpty), isTrue);
    expect(actionLibrary.every((item) => item.duration.isNotEmpty), isTrue);
    expect(actionLibrary.every((item) => item.instructions.isNotEmpty), isTrue);
  });

  test('keeps action wording out of medical treatment claims', () {
    final combinedText = actionLibrary
        .map((item) => '${item.name} ${item.instructions}')
        .join(' ');

    expect(combinedText, isNot(contains('治疗')));
    expect(combinedText, isNot(contains('诊断')));
    expect(combinedText, isNot(contains('治愈')));
  });
}
