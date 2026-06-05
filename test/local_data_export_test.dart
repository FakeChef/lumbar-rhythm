import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local export payload keeps app metadata and user data sections', () {
    final payload = {
      'schema_version': 1,
      'app': 'Lumbar Rhythm',
      'app_version': '0.1.0+1',
      'exported_at': DateTime(2026, 6, 5, 12).toIso8601String(),
      'privacy_note':
          'This file was created locally by user action. Lumbar Rhythm does not upload health data.',
      'record_count': 1,
      'setting_count': 1,
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
    };

    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    final decoded = jsonDecode(encoded) as Map<String, Object?>;

    expect(decoded['schema_version'], 1);
    expect(decoded['app'], 'Lumbar Rhythm');
    expect(decoded['app_version'], '0.1.0+1');
    expect(decoded['record_count'], 1);
    expect(decoded['setting_count'], 1);
    expect(decoded['settings'], isA<Map<String, Object?>>());
    expect(decoded['records'], isA<List<Object?>>());
    expect(decoded['privacy_note'], contains('does not upload health data'));
  });
}
