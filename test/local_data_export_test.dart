import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local export payload keeps app metadata and user data sections', () {
    final payload = {
      'app': 'Lumbar Rhythm',
      'exported_at': DateTime(2026, 6, 5, 12).toIso8601String(),
      'privacy_note': 'This file was created locally by user action.',
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

    expect(decoded['app'], 'Lumbar Rhythm');
    expect(decoded['settings'], isA<Map<String, Object?>>());
    expect(decoded['records'], isA<List<Object?>>());
    expect(decoded['privacy_note'], contains('locally'));
  });
}
