/// Pins the `CheckboxThemeData` contract added for the 2026-06-11 task
/// detail dark-mode pass. Without an explicit dark-theme entry,
/// Material's default checkbox fill / outline rendered low-contrast
/// against the project's dark navy surface, making both checked and
/// unchecked states hard to read in `IMG_1874.PNG`.
///
/// Uses `testWidgets` so the Flutter test binding initialises before
/// `AppTheme.dark()` / `light()` triggers GoogleFonts lookups inside
/// `AppTypography.textTheme`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';

void main() {
  group('AppTheme.dark() — checkboxTheme', () {
    testWidgets('fillColor resolves to AppColors.sageLight when selected', (
      _,
    ) async {
      final dark = AppTheme.dark();
      final fill = dark.checkboxTheme.fillColor?.resolve({
        WidgetState.selected,
      });
      expect(
        fill,
        AppColors.sageLight,
        reason: 'Checked checkboxes need a sage fill so the ✓ is visible',
      );
    });

    testWidgets('checkColor (the ✓ glyph) contrasts on the sage fill', (
      _,
    ) async {
      final dark = AppTheme.dark();
      final check = dark.checkboxTheme.checkColor?.resolve({
        WidgetState.selected,
      });
      expect(
        check,
        AppColors.charcoalDark,
        reason: '✓ glyph uses charcoalDark for AA contrast on sageLight',
      );
    });

    testWidgets(
      'outline (side) renders unchecked boxes visibly against dark surface',
      (_) async {
        final dark = AppTheme.dark();
        final side = dark.checkboxTheme.side;
        expect(side, isNotNull);
        expect(
          side!.color,
          AppColors.lightGrey,
          reason:
              'unchecked checkbox border must contrast against the dark '
              'navy surface; lightGrey is the project token for that role.',
        );
      },
    );
  });

  group('AppTheme.light() — checkboxTheme', () {
    testWidgets('declared explicitly so it is not silently Material default', (
      _,
    ) async {
      final light = AppTheme.light();
      expect(
        light.checkboxTheme.fillColor,
        isNotNull,
        reason:
            'Light + dark themes both declare a checkboxTheme for parity '
            'and to lock the look against future Material updates.',
      );
    });
  });
}
