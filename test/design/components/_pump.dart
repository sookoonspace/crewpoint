import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';

/// Pumps [child] alone under the design system's theme.
Future<void> pumpCp(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: CpTheme.light(),
      darkTheme: CpTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
}
