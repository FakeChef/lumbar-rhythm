import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_summary.dart';
import 'package:lumbar_rhythm/features/recovery/domain/daily_recovery_note.dart';
import 'package:lumbar_rhythm/features/recovery/domain/recovery_profile.dart';
import 'package:lumbar_rhythm/features/reports/domain/daily_report.dart';
import 'package:lumbar_rhythm/features/reports/presentation/follow_up_report_image.dart';

void main() {
  testWidgets('follow-up report image shows required sections and metrics',
      (tester) async {
    final generatedAt = DateTime(2026, 6, 7, 12);
    final report = DailyReport(
      profile: RecoveryProfile(
        id: 1,
        nickname: '小林',
        surgeryDate: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      ),
      rehabActions: actionLibrary,
      recentRehabLogs: [
        RehabLog(
          id: 1,
          actionId: 1,
          amount: '20',
          amountValue: 20,
          unit: '分钟',
          reaction: RehabReaction.noChange,
          source: 'manual',
          symptomTags: const ['腰酸'],
          note: null,
          createdAt: DateTime(2026, 6, 6, 10),
        ),
        RehabLog(
          id: 2,
          actionId: 9,
          amount: '5',
          amountValue: 5,
          unit: '分钟',
          reaction: RehabReaction.muchWorse,
          source: 'manual',
          symptomTags: const ['腰酸', '腿麻'],
          note: null,
          createdAt: DateTime(2026, 6, 7, 10),
        ),
      ],
      recentDailyNotes: [
        DailyRecoveryNote(
          date: DateTime(2026, 6, 7),
          overallFeeling: OverallFeeling.same,
          backPainScore: 4,
          legSymptomScore: 3,
          fatigueScore: 5,
          note: '上午活动后休息了一会儿。',
          createdAt: DateTime(2026, 6, 7),
          updatedAt: DateTime(2026, 6, 7),
        ),
      ],
      postureSummary: PostureSummary(
        sessions: const [],
        now: generatedAt,
      ),
      recentPostureSummary: PostureSummary(
        now: generatedAt,
        sessions: [
          PostureSession(
            id: 1,
            type: PostureType.sitting,
            startedAt: DateTime(2026, 6, 7, 8),
            endedAt: DateTime(2026, 6, 7, 9),
            durationSeconds: 3600,
            exceededSeconds: 900,
          ),
          PostureSession(
            id: 2,
            type: PostureType.standing,
            startedAt: DateTime(2026, 6, 7, 9),
            endedAt: DateTime(2026, 6, 7, 9, 30),
            durationSeconds: 1800,
          ),
        ],
      ),
    );

    await _pumpReportImage(tester, report, generatedAt);

    expect(find.text('腰椎节奏复诊记录摘要'), findsOneWidget);
    expect(find.text('坐站节奏'), findsOneWidget);
    expect(find.text('康复活动'), findsOneWidget);
    expect(find.text('身体状态'), findsOneWidget);
    expect(find.text('备注摘要'), findsOneWidget);
    expect(find.text('腰酸、腿麻'), findsOneWidget);
    expect(find.text(followUpReportDisclaimer), findsOneWidget);
  });

  testWidgets('follow-up report image uses calm empty states', (tester) async {
    final generatedAt = DateTime(2026, 6, 7, 12);
    final report = DailyReport(
      postureSummary: PostureSummary(sessions: const [], now: generatedAt),
      recentPostureSummary:
          PostureSummary(sessions: const [], now: generatedAt),
    );

    await _pumpReportImage(tester, report, generatedAt);

    expect(find.text('暂无记录'), findsNWidgets(3));
    expect(find.text('暂无症状标签记录'), findsOneWidget);
    expect(find.text('暂无备注记录'), findsOneWidget);
  });

  test('follow-up report copy avoids unsupported medical wording', () {
    final source = File(
      'lib/features/reports/presentation/follow_up_report_image.dart',
    ).readAsStringSync().replaceAll(followUpReportDisclaimer, '');
    const forbidden = [
      '治疗',
      '治愈',
      '预防复发',
      '诊断',
      '复发判断',
      '复发风险',
      '病情判断',
      '医疗建议',
    ];

    for (final word in forbidden) {
      expect(source, isNot(contains(word)));
    }
  });
}

Future<void> _pumpReportImage(
  WidgetTester tester,
  DailyReport report,
  DateTime generatedAt,
) async {
  await tester.binding.setSurfaceSize(const Size(720, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FollowUpReportImage(
            report: report,
            generatedAt: generatedAt,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
