import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/join_event_sheet.dart';

import '../../../../core/_helpers/wcag_contrast.dart';

Future<void> _pumpWithTheme(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Theme(
        data: theme,
        child: const Scaffold(body: JoinEventSheet()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'code TextField fillColor comes from inputDecorationTheme (not hard-coded)',
    (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await _pumpWithTheme(tester, theme);
        final field = tester.widget<TextField>(find.byType(TextField));
        // The sheet must not override fillColor anymore — it should fall
        // through to InputDecorationTheme so each app theme can supply
        // its own surface color.
        expect(
          field.decoration!.fillColor,
          isNull,
          reason:
              'JoinEventSheet should not hard-code fillColor in '
              '${theme.brightness} theme; inputDecorationTheme.fillColor wins',
        );
      }
    },
  );

  testWidgets(
    'typed-text color meets WCAG AA against the active fillColor in BOTH themes',
    (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await _pumpWithTheme(tester, theme);
        final field = tester.widget<TextField>(find.byType(TextField));
        // Background: prefer the input field's effective fillColor; fall
        // back to inputDecorationTheme.fillColor when the field doesn't
        // override it.
        final bg =
            field.decoration!.fillColor ??
            theme.inputDecorationTheme.fillColor!;
        // Typed text color: TextField.style ?? theme's body large.
        final fg =
            field.style?.color ??
            theme.textTheme.headlineMedium?.color ??
            theme.colorScheme.onSurface;
        expectAaContrast(
          fg,
          bg,
          reason: 'typed-code contrast in ${theme.brightness} theme',
        );
      }
    },
  );

  testWidgets('hint color contrast ≥ 3.0 against fill in BOTH themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await _pumpWithTheme(tester, theme);
      final field = tester.widget<TextField>(find.byType(TextField));
      final bg =
          field.decoration!.fillColor ?? theme.inputDecorationTheme.fillColor!;
      final hintColor = field.decoration!.hintStyle!.color!;
      expectAaContrast(
        hintColor,
        bg,
        minimum: 3.0,
        reason: 'hint contrast in ${theme.brightness} theme',
      );
    }
  });
}
