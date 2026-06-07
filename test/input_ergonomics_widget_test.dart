import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/actions/presentation/actions_page.dart';

void main() {
  testWidgets('rehab log sheet uses chips steppers and collapsed note',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RehabLogSheet(
            action: RehabAction(
              id: 1,
              name: '平地步行',
              defaultUnit: '分钟',
              optionalUnits: ['分钟', '次/天'],
              guidance: '按舒适节奏记录。',
            ),
          ),
        ),
      ),
    );

    expect(find.widgetWithText(TextField, '完成量'), findsNothing);
    expect(find.widgetWithText(TextField, '单位'), findsNothing);
    expect(
        find.byKey(const ValueKey('rehab-quick-amount-3-分钟')), findsOneWidget);
    expect(find.byKey(const ValueKey('rehab-amount-stepper-value')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('rehab-unit-options')), findsOneWidget);
    expect(find.text('分钟'), findsWidgets);
    expect(find.text('次/天'), findsWidgets);
    expect(find.byKey(const ValueKey('optional-note-toggle')), findsOneWidget);
    expect(find.byKey(const ValueKey('optional-note-field')), findsNothing);
  });

  testWidgets('daily recovery note sheet uses sliders and collapsed note',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyRecoveryNoteSheet(),
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('daily-feeling-segmented')), findsOneWidget);
    expect(find.text('好一点'), findsOneWidget);
    expect(find.text('差不多'), findsOneWidget);
    expect(find.text('有点加重'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('daily-back-pain-slider')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('daily-leg-symptom-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-fatigue-slider')), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.byKey(const ValueKey('optional-note-toggle')), findsOneWidget);
    expect(find.byKey(const ValueKey('optional-note-field')), findsNothing);
  });

  test('README keeps bottom navigation order in sync', () {
    final readme = File('README.md').readAsStringSync().replaceAll('\r\n', '\n');
    const expected = '''
当前底部导航页面包括：

- 今日。
- 康复。
- 日历。
- 报告。
- 设置。''';

    expect(readme, contains(expected));
  });
}
