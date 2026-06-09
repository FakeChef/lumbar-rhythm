import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android manifest disables system backup for local health data', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );

    final dataExtractionRules =
        File('android/app/src/main/res/xml/data_extraction_rules.xml')
            .readAsStringSync();

    for (final section in ['cloud-backup', 'device-transfer']) {
      expect(dataExtractionRules, contains('<$section>'));
    }
    for (final domain in [
      'root',
      'file',
      'database',
      'sharedpref',
      'external'
    ]) {
      expect(dataExtractionRules, contains('domain="$domain" path="."'));
    }
  });
}
