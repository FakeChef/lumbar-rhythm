import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v0.4.3 keeps sit-walk home flow focused', () {
    final home = File('lib/features/home/presentation/home_page.dart')
        .readAsStringSync();

    expect(home, contains("ValueKey('today-posture-sitting')"));
    expect(home, contains("ValueKey('today-posture-walking')"));
    expect(home, contains("ValueKey('today-posture-stop')"));
    expect(home, contains("ValueKey('today-daytime-cycle-start')"));
    expect(home, contains("ValueKey('today-cycle-next-phase')"));
    expect(home, contains('我在坐'));
    expect(home, contains('我在走'));
    expect(home, contains('今日提醒次数'));
    expect(home, contains('今日停止次数'));
    expect(home, isNot(contains('我在站')));
    expect(home, isNot(contains('我在休息')));
    expect(home, isNot(contains("ValueKey('today-add-rehab-log')")));
    expect(home, isNot(contains('+ 添加康复记录')));
    expect(home, isNot(contains('我去走动了')));
  });

  test('v0.4.3 moves rehab add entry to rehab tab', () {
    final actions = File('lib/features/actions/presentation/actions_page.dart')
        .readAsStringSync();

    expect(actions, contains("ValueKey('rehab-add-log')"));
    expect(actions, contains('+ 添加康复记录'));
  });

  test('v0.4.3 exposes daytime rhythm settings', () {
    final settings =
        File('lib/features/settings/presentation/settings_page.dart')
            .readAsStringSync();

    expect(settings, contains('白天节奏'));
    expect(settings, contains('开始时间'));
    expect(settings, contains('结束时间'));
    expect(settings, contains('坐姿阶段'));
    expect(settings, contains('走动阶段'));
  });

  test('v0.4.3 saves current report and shows range trends', () {
    final reports = File('lib/features/reports/presentation/reports_page.dart')
        .readAsStringSync();
    final reportImage =
        File('lib/features/reports/presentation/follow_up_report_image.dart')
            .readAsStringSync();

    expect(reports, contains('保存当前报告到相册'));
    expect(reports, contains('lumbar-rhythm-report-\${period.name}-'));
    expect(reports, contains("ValueKey('report-posture-trend-chart')"));
    expect(reports, contains('最近 7 天康复柱状图'));
    expect(reports, contains('最近 30 天康复柱状图'));
    expect(reportImage, contains('useCurrentRange'));
    expect(reportImage, contains('rangeLabel'));
    expect(reportImage, contains('本报告仅用于个人康复记录回顾'));
  });

  test('v0.4.3 wires walking reminders through local-only services', () {
    final notifications =
        File('lib/core/notifications/notification_service.dart')
            .readAsStringSync();
    final controller =
        File('lib/features/posture/application/posture_session_controller.dart')
            .readAsStringSync();
    final repository =
        File('lib/features/posture/data/posture_session_repository.dart')
            .readAsStringSync();

    expect(notifications, contains('ReminderKind.walking'));
    expect(notifications, contains('walkingIntervalMinutes'));
    expect(controller, contains('startWalking'));
    expect(controller, contains('showPostureDueReminder'));
    expect(repository, contains('walkingThresholdMinutes'));
    expect(notifications, isNot(contains('http://')));
    expect(notifications, isNot(contains('https://')));
  });
}
