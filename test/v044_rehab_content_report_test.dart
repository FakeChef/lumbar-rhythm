import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/home/domain/stage_encouragement_messages.dart';

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
    expect(stageEncouragementMessages['P1']?.length, 30);
    expect(stageEncouragementMessages['P2']?.length, 30);
    expect(stageEncouragementMessages['P3']?.length, 30);
    expect(stageEncouragementMessages['P4']?.length, 30);
    expect(home, contains('stageEncouragementFor'));
    expect(home, contains('stageEncouragementFallback'));
    expect(home, isNot(contains('当前记录阶段')));
    expect(home, isNot(contains('阶段一')));
    expect(home, isNot(contains('阶段二')));
    expect(home, isNot(contains('阶段三')));
    expect(home, isNot(contains('阶段四')));
    expect(home, isNot(contains('当前阶段')));

    final reports = File('lib/features/reports/presentation/reports_page.dart')
        .readAsStringSync();
    expect(reports, contains('回顾你的康复动作记录和阶段活动'));
    expect(reports, contains('今日康复动作记录'));
    expect(reports, contains('最近 7 天按活动趋势'));
    expect(reports, contains('最近 30 天按活动趋势'));
    expect(reports, contains('左右滑动查看 30 天趋势'));
    expect(reports, contains('按实际记录过的康复活动查看趋势'));
    expect(reports, isNot(contains('最近 7 天康复汇总')));
    expect(reports, isNot(contains('最近 30 天康复柱状图')));
    expect(reports, isNot(contains('今日坐姿状态')));
    expect(reports, isNot(contains('今日坐姿累计')));

    final actions = File('lib/features/actions/presentation/actions_page.dart')
        .readAsStringSync();
    expect(actions, contains('ValueKey(\'rehab-activity-dropdown\')'));
    expect(actions, isNot(contains('ValueKey(\'rehab-category-dropdown\')')));
    expect(actions, isNot(contains('ValueKey(\'rehab-add-log\')')));

    final combinedText = [
      home,
      reports,
      actions,
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
