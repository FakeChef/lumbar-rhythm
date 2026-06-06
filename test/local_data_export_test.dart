import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local export payload keeps app metadata and user data sections', () {
    final payload = {
      'schema_version': 2,
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
          'unit': '分钟',
          'reaction': 'noChange',
          'created_at': DateTime(2026, 6, 5, 11).toIso8601String(),
        },
      ],
    };

    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    final decoded = jsonDecode(encoded) as Map<String, Object?>;

    expect(decoded['schema_version'], 2);
    expect(decoded['app'], 'Lumbar Rhythm');
    expect(decoded['app_version'], '0.1.0+1');
    expect(decoded['record_count'], 1);
    expect(decoded['setting_count'], 1);
    expect(decoded['settings'], isA<Map<String, Object?>>());
    expect(decoded['records'], isA<List<Object?>>());
    expect(decoded['posture_sessions'], isA<List<Object?>>());
    expect(decoded['rehab_actions'], isA<List<Object?>>());
    expect(decoded['rehab_logs'], isA<List<Object?>>());
    expect(decoded['privacy_note'], contains('does not upload health data'));
  });
}
