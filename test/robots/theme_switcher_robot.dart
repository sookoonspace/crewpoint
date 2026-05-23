import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Intent-centric helpers for the Theme Switcher journey. Selectors must
/// match the keys declared in `profile_screen.dart` (the `_ThemeRow`) and
/// `theme_switcher_sheet.dart`.
class ThemeSwitcherRobot {
  ThemeSwitcherRobot(this.tester);

  final WidgetTester tester;

  /// Lottie loops in Profile/Tasks empty states would deadlock
  /// `pumpAndSettle`; bounded pumps keep the robot deterministic.
  Future<void> _bounded({int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openSheet() async {
    final row = find.byKey(const Key('profile.theme.row'));
    await tester.ensureVisible(row);
    await _bounded();
    await tester.tap(row);
    await _bounded();
  }

  Future<void> tapDark() async {
    await tester.tap(find.byKey(const Key('profile.theme.sheet.option.dark')));
    await _bounded();
  }

  Future<void> tapLight() async {
    await tester.tap(find.byKey(const Key('profile.theme.sheet.option.light')));
    await _bounded();
  }

  void expectSheetVisible() {
    expect(find.byKey(const Key('profile.theme.sheet')), findsOneWidget);
  }

  void expectSheetDismissed() {
    expect(find.byKey(const Key('profile.theme.sheet')), findsNothing);
  }

  void expectTrailingLabel(String label) {
    final finder = find.byKey(const Key('profile.theme.row.trailing'));
    expect(finder, findsOneWidget);
    expect(tester.widget<Text>(finder).data, label);
  }
}
