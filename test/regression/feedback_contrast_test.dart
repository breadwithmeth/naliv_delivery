import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';

void main() {
  for (final entry
      in {'light': AppTheme.light(), 'dark': AppTheme.dark()}.entries) {
    test('${entry.key} feedback text remains readable on its container', () {
      final feedback = entry.value.snackBarTheme;
      final foreground = feedback.contentTextStyle!.color!.computeLuminance();
      final background = feedback.backgroundColor!.computeLuminance();
      final contrast = (math.max(foreground, background) + 0.05) /
          (math.min(foreground, background) + 0.05);

      expect(contrast, greaterThanOrEqualTo(4.5),
          reason: 'Storage and recovery feedback must be readable.');
    });
  }
}
