import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_scales.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_type.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/design/tokens/wcag.dart';

void main() {
  group('CpTheme', () {
    for (final (name, theme, colors, brightness) in [
      ('light', CpTheme.light(), CpColors.light, Brightness.light),
      ('dark', CpTheme.dark(), CpColors.dark, Brightness.dark),
    ]) {
      group(name, () {
        test('carries every token extension', () {
          expect(theme.brightness, brightness);
          expect(theme.extension<CpColors>(), colors);
          expect(theme.extension<CpType>(), CpType.standard);
          expect(theme.extension<CpSpacing>(), isNotNull);
          expect(theme.extension<CpRadii>(), isNotNull);
          expect(theme.extension<CpSizes>(), isNotNull);
          expect(theme.extension<CpMotion>(), isNotNull);
          expect(theme.extension<CpShadows>(), isNotNull);
        });

        test('builds the colour scheme from the tokens', () {
          final scheme = theme.colorScheme;
          expect(scheme.primary, colors.accent);
          expect(scheme.onPrimary, colors.onAccent);
          expect(scheme.surface, colors.surface);
          expect(scheme.onSurface, colors.text);
          expect(scheme.onSurfaceVariant, colors.textMuted);
          expect(scheme.error, colors.overdue);
          expect(scheme.outline, colors.border);
          expect(theme.scaffoldBackgroundColor, colors.background);
        });

        test('sets every text style in Inter, headings in Inter Display', () {
          final text = theme.textTheme;
          expect(text.bodyMedium?.fontFamily, CpType.textFont);
          expect(text.labelLarge?.fontFamily, CpType.textFont);
          expect(text.headlineLarge?.fontFamily, CpType.displayFont);
          expect(text.titleLarge?.fontFamily, CpType.displayFont);
          expect(text.bodyMedium?.color, colors.text);
        });

        test('keeps body text and accent buttons readable (WCAG AA)', () {
          for (final (fg, bg) in [
            (colors.text, colors.background),
            (colors.text, colors.surface),
            (colors.textMuted, colors.surface),
            (colors.textMuted, colors.background),
            (colors.onAccent, colors.accent),
            (colors.done, colors.doneSoft),
            (colors.due, colors.dueSoft),
            (colors.overdue, colors.overdueSoft),
            (colors.onBanner, colors.banner),
          ]) {
            expect(
              contrastRatio(fg, bg),
              greaterThanOrEqualTo(kWcagAaBodyText),
              reason: '$fg on $bg',
            );
          }
        });
      });
    }

    test('light and dark differ only in token values', () {
      final light = CpTheme.light();
      final dark = CpTheme.dark();
      expect(light.extension<CpType>(), same(dark.extension<CpType>()));
      expect(
        light.textTheme.bodyMedium?.fontSize,
        dark.textTheme.bodyMedium?.fontSize,
      );
      expect(light.extension<CpColors>(), isNot(dark.extension<CpColors>()));
    });
  });

  testWidgets('context.cp reads the tokens of the nearest theme', (
    tester,
  ) async {
    late CpTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: CpTheme.light(),
        darkTheme: CpTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            tokens = context.cp;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(tokens.colors, CpColors.dark);
    expect(tokens.space.lg, 16);
    expect(tokens.type, CpType.standard);
  });

  testWidgets('context.cp falls back to the light tokens without CpTheme', (
    tester,
  ) async {
    late CpTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            tokens = context.cp;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(tokens.colors, CpColors.light);
  });
}
