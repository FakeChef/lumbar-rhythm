import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/features/actions/domain/action_item.dart';
import 'package:lumbar_rhythm/features/calendar/domain/calendar_day_status.dart';
import 'package:lumbar_rhythm/features/calendar/presentation/calendar_day_detail_page.dart';
import 'package:lumbar_rhythm/features/posture/domain/posture_session.dart';
import 'package:lumbar_rhythm/features/recovery/domain/daily_recovery_note.dart';
import 'package:lumbar_rhythm/features/recovery/domain/recovery_profile.dart';

void main() {
  testWidgets('day detail page displays daily, posture, and rehab data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final day = DateTime(2026, 6, 7);
    final status = CalendarDayStatus(
      date: day,
      actions: actionLibrary,
      profile: RecoveryProfile(
        id: 1,
        surgeryDate: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      ),
      note: DailyRecoveryNote(
        date: day,
        overallFeeling: OverallFeeling.same,
        backPainScore: 2,
        legSymptomScore: 1,
        fatigueScore: 3,
        tags: const ['疲劳'],
        note: '今天平稳',
        createdAt: day,
        updatedAt: day,
      ),
      postureSessions: [
        PostureSession(
          id: 1,
          type: PostureType.sitting,
          startedAt: DateTime(2026, 6, 7, 8),
          endedAt: DateTime(2026, 6, 7, 9),
          durationSeconds: 3600,
          thresholdSeconds: 2700,
          exceededSeconds: 900,
        ),
        PostureSession(
          id: 2,
          type: PostureType.walking,
          startedAt: DateTime(2026, 6, 7, 9),
          endedAt: DateTime(2026, 6, 7, 9, 10),
          durationSeconds: 600,
        ),
      ],
      rehabLogs: [
        RehabLog(
          id: 1,
          actionId: 1,
          amount: '12',
          amountValue: 12,
          unit: '分钟',
          reaction: RehabReaction.muchWorse,
          source: 'manual',
          symptomTags: const ['腰酸'],
          note: '量有点多',
          createdAt: DateTime(2026, 6, 7, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: CalendarDayDetailPage(status: status)),
    );

    expect(find.text('2026 年 6 月 7 日'), findsOneWidget);
    expect(find.text('术后第 7 天'), findsOneWidget);
    expect(find.text('每日状态'), findsOneWidget);
    expect(find.text('差不多'), findsOneWidget);
    expect(find.text('坐姿累计'), findsOneWidget);
    expect(find.text('1 小时 0 分钟'), findsWidgets);
    expect(find.text('超阈值次数'), findsOneWidget);
    expect(find.text('步行'), findsOneWidget);
    expect(find.text('12 分钟 · 明显加重'), findsOneWidget);
    expect(find.text('症状标签：腰酸'), findsOneWidget);
    expect(find.text('建议减少量、暂停观察，必要时咨询医生或康复师。'), findsOneWidget);
  });
}
