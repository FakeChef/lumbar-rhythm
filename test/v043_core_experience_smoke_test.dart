import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home keeps manual sit stand rest flow focused', () {
    final home = File('lib/features/home/presentation/home_page.dart')
        .readAsStringSync();

    expect(home, contains("ValueKey('today-posture-sitting')"));
    expect(home, contains("ValueKey('today-posture-standing')"));
    expect(home, contains("ValueKey('today-posture-stop')"));
    final primaryStart = home.indexOf('const primaryPostures = [');
    final primaryEnd = home.indexOf('];', primaryStart);
    final primaryPostures = home.substring(primaryStart, primaryEnd);
    expect(primaryPostures, isNot(contains('PostureType.walking')));
    expect(home, isNot(contains("ValueKey('today-add-rehab-log')")));
    expect(home, isNot(contains('+ 添加康复记录')));
    expect(home, isNot(contains('白天节奏')));
  });
  test('v0.4.3 moves rehab add entry to rehab tab', () {
    final actions = File('lib/features/actions/presentation/actions_page.dart')
        .readAsStringSync();

    expect(actions, contains("ValueKey('rehab-add-entry-button')"));
    expect(actions, contains("ValueKey('rehab-activity-dropdown')"));
    expect(actions, contains('添加康复记录'));
    expect(actions, isNot(contains("ValueKey('rehab-category-dropdown')")));
    expect(actions, isNot(contains("ValueKey('rehab-add-log')")));
  });

  test('settings exposes manual countdown reminder copy', () {
    final settings =
        File('lib/features/settings/presentation/settings_page.dart')
            .readAsStringSync();

    expect(settings, contains('前台倒计时会话'));
    expect(settings, contains('点击“我在坐”或“我在站”后开始计时'));
    expect(settings, contains('准时提醒权限未开启时会继续倒计时'));
    expect(settings, isNot(contains('自动循环提醒')));
    expect(settings, isNot(contains('全天节奏提醒')));
  });

  test('v0.4.3 saves current report and shows range trends', () {
    final reports = File('lib/features/reports/presentation/reports_page.dart')
        .readAsStringSync();
    final reportImage =
        File('lib/features/reports/presentation/follow_up_report_image.dart')
            .readAsStringSync();

    expect(reports, contains('保存当前报告到相册'));
    expect(reports, contains('lumbar-rhythm-report-\${period.name}-'));
    expect(reports, contains("ValueKey('rehab-activity-trend-chart-"));
    expect(reports, contains('最近 7 天按活动趋势'));
    expect(reports, contains('最近 30 天按活动趋势'));
    expect(reports, isNot(contains('左右滑动查看 30 天趋势')));
    expect(reports, isNot(contains('reverse: true')));
    expect(reports, contains('minimumHeight = value == 0 ? 4.0 : 18.0'));
    expect(reports, isNot(contains("ValueKey('report-rehab-trend-chart')")));
    expect(reports, isNot(contains('最近 7 天康复柱状图')));
    expect(reports, isNot(contains('最近 30 天康复柱状图')));
    expect(reportImage, contains('useCurrentRange'));
    expect(reportImage, contains('rangeLabel'));
    expect(reportImage, contains('本报告仅用于个人康复记录回顾'));
  });

  test('walking records remain local and do not schedule posture reminders',
      () {
    final notifications =
        File('lib/core/notifications/notification_service.dart')
            .readAsStringSync();
    final controller =
        File('lib/features/posture/application/posture_session_controller.dart')
            .readAsStringSync();
    final repository =
        File('lib/features/posture/data/posture_session_repository.dart')
            .readAsStringSync();

    expect(notifications, contains('PostureType.walking'));
    expect(notifications, isNot(contains('ReminderKind.walking')));
    expect(notifications, contains('walkingIntervalMinutes'));
    expect(notifications, contains('startPostureCountdown'));
    expect(controller, contains('startWalking'));
    expect(controller, contains('stopPostureCountdown'));
    expect(controller, isNot(contains('showPostureDueReminder')));
    expect(repository, contains('walkingThresholdMinutes'));
    expect(notifications, isNot(contains('http://')));
    expect(notifications, isNot(contains('https://')));
  });
}
