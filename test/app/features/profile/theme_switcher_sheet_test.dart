import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/theme_switcher_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpSheet(WidgetTester tester, SharedPreferences prefs) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: Scaffold(body: ThemeSwitcherSheet())),
      ),
    );
  }

  testWidgets('renders System / Light / Dark options', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await pumpSheet(tester, prefs);

    expect(find.byKey(const Key('profile.theme.sheet')), findsOneWidget);
    expect(
      find.byKey(const Key('profile.theme.sheet.option.system')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile.theme.sheet.option.light')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile.theme.sheet.option.dark')),
      findsOneWidget,
    );
  });

  testWidgets('tapping Dark flips themeModeProvider to dark and pops', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Builder(
            builder: (innerContext) {
              container = ProviderScope.containerOf(innerContext);
              return Scaffold(
                body: Builder(
                  builder: (ctx) => Center(
                    child: ElevatedButton(
                      key: const Key('open.sheet'),
                      onPressed: () => ThemeSwitcherSheet.show(ctx),
                      child: const Text('open'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open.sheet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile.theme.sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile.theme.sheet.option.dark')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile.theme.sheet')), findsNothing);
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('tapping Light flips themeModeProvider to light and pops', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Builder(
            builder: (innerContext) {
              container = ProviderScope.containerOf(innerContext);
              return Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('open.sheet'),
                    onPressed: () => ThemeSwitcherSheet.show(ctx),
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open.sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile.theme.sheet.option.light')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile.theme.sheet')), findsNothing);
    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
