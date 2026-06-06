import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local export payload keeps app metadata and user data sections', () {
    final payload = {
      'schema_version': 3,
      'app': 'Lumbar Rhythm',
      'app_version': '0.1.0+1',
      'exported_at': DateTime(2026, 6, 5, 12).toIso8601String(),
      'privacy_note':
          'This file was created locally by user action. Lumbar Rhythm does not upload health data.',
      'record_count': 1,
      'setting_count': 1,
      'posture_session_count': 1,
      'rehab_action_count': 1,
      'rehab_log_count': 1,
      'daily_recovery_note_count': 1,
      'recovery_milestone_count': 1,
      'settings': {
        'reminders_enabled': 'true',
      },
      'records': [
        {
          'id': 1,
          'type': 'stretch',
          'note': 'completed action',
          'created_at': DateTime(2026, 6, 5, 10).toIso8601String(),
        },
      ],
      'posture_sessions': [
        {
          'id': 1,
          'type': 'sitting',
          'started_at': DateTime(2026, 6, 5, 9).toIso8601String(),
          'ended_at': DateTime(2026, 6, 5, 10).toIso8601String(),
          'duration_seconds': 3600,
        },
      ],
      'rehab_actions': [
        {
          'id': 1,
          'name': '步行',
          'default_unit': '分钟',
          'guidance': '按自己舒适节奏记录一次步行。',
          'sort_order': 1,
        },
      ],
      'rehab_logs': [
        {
          'id': 1,
          'action_id': 1,
          'amount': '10',
          'amount_value': 10.0,
          'unit': '分钟',
          'reaction': 'noChange',
          'source': 'manual',
          'created_at': DateTime(2026, 6, 5, 11).toIso8601String(),
        },
      ],
      'recovery_profile': {
        'id': 1,
        'surgery_date': '2026-06-01',
      },
      'daily_recovery_notes': [
        {
          'date': '2026-06-05',
          'overall_feeling': 'same',
          'back_pain_score': 2,
          'leg_symptom_score': 1,
          'fatigue_score': 3,
        },
      ],
      'recovery_milestones': [
        {
          'id': 1,
          'title': '第一周康复日志',
          'status': 'planned',
        },
      ],
    };

    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    final decoded = jsonDecode(encoded) as Map<String, Object?>;

    expect(decoded['schema_version'], 3);
    expect(decoded['app'], 'Lumbar Rhythm');
    expect(decoded['app_version'], '0.1.0+1');
    expect(decoded['record_count'], 1);
    expect(decoded['setting_count'], 1);
    expect(decoded['settings'], isA<Map<String, Object?>>());
    expect(decoded['records'], isA<List<Object?>>());
    expect(decoded['posture_sessions'], isA<List<Object?>>());
    expect(decoded['rehab_actions'], isA<List<Object?>>());
    expect(decoded['rehab_logs'], isA<List<Object?>>());
    expect(decoded['recovery_profile'], isA<Map<String, Object?>>());
    expect(decoded['daily_recovery_notes'], isA<List<Object?>>());
    expect(decoded['recovery_milestones'], isA<List<Object?>>());
    expect(decoded['privacy_note'], contains('does not upload health data'));
  });
}
