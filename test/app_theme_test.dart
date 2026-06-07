import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumbar_rhythm/core/theme/app_theme.dart';

void main() {
  test('AppTheme uses Material 3 and the calm blue palette', () {
    final theme = AppTheme.light;
    final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, const Color(0xFF6B9AC4));
    expect(theme.cardTheme.elevation, 0);
    expect(cardShape.borderRadius, BorderRadius.circular(16));
  });
}
