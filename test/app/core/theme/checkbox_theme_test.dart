/// Pins the checkbox colours in both themes: checked boxes fill with the
/// accent and show the on-accent tick; unchecked boxes keep a visible
/// muted outline on the dark surface (first flagged in `IMG_1874.PNG`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';

void main() {
  for (final (name, theme, colors) in [
    ('light', CpTheme.light(), CpColors.light),
    ('dark', CpTheme.dark(), CpColors.dark),
  ]) {
    group('CpTheme.$name() checkboxTheme', () {
      test('fills a checked box with the accent', () {
        expect(
          theme.checkboxTheme.fillColor?.resolve({WidgetState.selected}),
          colors.accent,
        );
      });

      test('draws the tick in the on-accent colour', () {
        expect(
          theme.checkboxTheme.checkColor?.resolve({WidgetState.selected}),
          colors.onAccent,
        );
      });

      test('outlines an unchecked box in the muted text colour', () {
        expect(theme.checkboxTheme.side?.color, colors.textMuted);
      });
    });
  }
}
