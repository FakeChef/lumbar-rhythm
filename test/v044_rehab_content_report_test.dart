import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';

void main() {
  test('v0.4.4 rehab content and report direction stay focused', () {
    expect(activityMasterV1.length, 25);

    final highRiskActivities =
        activityMasterV1.where((activity) => activity.riskLevel == 'high');
    expect(highRiskActivities, isNotEmpty);
    expect(
      highRiskActivities.every((activity) => activity.requiresDoctorClearance),
      isTrue,
    );

    final home = File('lib/features/home/presentation/home_page.dart')
        .readAsStringSync();
    expect(home, contains('当前记录阶段'));

    final reports = File('lib/features/reports/presentation/reports_page.dart')
        .readAsStringSync();
    expect(reports, contains('回顾你的康复动作记录和阶段活动'));
    expect(reports, contains('今日康复动作记录'));
    expect(reports, contains('最近 7 天康复汇总'));
    expect(reports, contains('最近 30 天康复柱状图'));
    expect(reports, isNot(contains('今日坐姿状态')));
    expect(reports, isNot(contains('今日坐姿累计')));

    final combinedText = [
      home,
      reports,
      File('lib/features/actions/domain/action_item.dart').readAsStringSync(),
    ].join('\n').replaceAll('本报告仅用于个人康复记录回顾，不作为专业判断依据。', '');

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
}
