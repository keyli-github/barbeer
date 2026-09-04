import 'package:barbeer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final mode = theme.brightness.name;
    test('$mode ColorScheme foregrounds meet AA contrast', () {
      final scheme = theme.colorScheme;
      final pairs = <(Color, Color)>[
        (scheme.primary, scheme.onPrimary),
        (scheme.secondary, scheme.onSecondary),
        (scheme.primaryContainer, scheme.onPrimaryContainer),
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
        (scheme.error, scheme.onError),
        (scheme.errorContainer, scheme.onErrorContainer),
        (scheme.inverseSurface, scheme.onInverseSurface),
      ];

      for (final pair in pairs) {
        expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    });

    test('$mode tooltip uses inverse surface colors', () {
      final decoration = theme.tooltipTheme.decoration! as BoxDecoration;
      expect(decoration.color, theme.colorScheme.inverseSurface);
      expect(
        theme.tooltipTheme.textStyle?.color,
        theme.colorScheme.onInverseSurface,
      );
    });

    test('$mode selected chips keep readable foreground contrast', () {
      final background = theme.chipTheme.selectedColor!;
      final foreground = theme.chipTheme.secondaryLabelStyle!.color!;

      expect(_contrast(background, foreground), greaterThanOrEqualTo(4.5));
    });
  }
}
