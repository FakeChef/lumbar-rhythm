import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';

void main() {
  test('provides activity master v1 with 25 core activities', () {
    expect(activityMasterV1.length, 25);
    expect(actionLibrary.length, 25);
    expect(activityMasterV1.map((item) => item.id).toSet(), hasLength(25));
    expect(
        activityMasterV1.every((item) => item.patientTip.isNotEmpty), isTrue);
    expect(activityMasterV1.every((item) => item.stopRule.isNotEmpty), isTrue);
    expect(activityMasterV1.every((item) => item.optionalUnits.isNotEmpty),
        isTrue);
    expect(activityMasterV1.every((item) => item.riskLevel.isNotEmpty), isTrue);
  });

  test('keeps action wording out of medical treatment claims', () {
    final combinedText = activityMasterV1
        .map(
          (item) =>
              '${item.nameCn} ${item.defaultUnit} ${item.patientTip} ${item.stopRule}',
        )
        .join(' ');

    for (final forbidden in [
      '治疗',
      '治愈',
      '预防复发',
      '诊断',
      '复发判断',
      '复发风险',
      '病情判断',
      '医疗建议',
    ]) {
      expect(combinedText, isNot(contains(forbidden)));
    }
  });

  test('maps legacy int action ids to new activity names', () {
    expect(legacyActionNameForId(1), '短距离步行');
    expect(legacyActionNameForId(3), '膈式呼吸');
    expect(legacyActionNameForId(8), '四足位对侧抬起');
    expect(legacyActionNameForId(10), '圆木滚动转身');
  });
}
