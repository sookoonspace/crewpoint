// Spec #233 Req 56 and the quality floor: the language switch before sign-in
// changes the app's language, and a screen in Gujarati fits 320 px with 200%
// text using the bundled Gujarati font.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/i18n/app_language.dart';
import 'package:crewpoint_app/app/core/i18n/app_language_rebuilder.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/i18n/script_fonts.dart';
import 'package:crewpoint_app/app/core/providers.dart' show authProvider;
import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';
import 'package:crewpoint_app/app/core/widgets/language_switch.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/presentation/auth_gate_screen.dart';
import 'package:crewpoint_app/l10n/gen/app_localizations.dart';

import '../app/features/auth/fake_auth_service.dart';

/// The app's localisation wiring, as `MyApp` sets it up.
class _App extends ConsumerWidget {
  const _App({required this.home, this.dark = false});

  final Widget home;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: dark ? CpTheme.dark() : CpTheme.light(),
    locale: ref.watch(appLanguageProvider).locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => AppLanguageRebuilder(
      locale: ref.watch(appLanguageProvider).locale,
      child: child!,
    ),
    home: home,
  );
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => Text(
    context.strings.language.title,
    key: const Key('test.language.title'),
  );
}

/// Reads strings in initState, as AddMemberSheet does, and keeps a count.
class _Stateful extends StatefulWidget {
  const _Stateful();

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  late final String first = context.strings.language.title;
  int taps = 0;

  @override
  void initState() {
    super.initState();
    first;
  }

  @override
  Widget build(BuildContext context) => TextButton(
    key: const Key('test.stateful'),
    onPressed: () => setState(() => taps++),
    child: Text('$taps ${context.strings.language.title}'),
  );
}

void main() {
  late FakeAuthService auth;
  late SharedPreferences prefs;

  setUp(() async {
    auth = FakeAuthService();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () =>
                AuthNotifier(authRepository: AuthRepository(authService: auth)),
          ),
        ],
        child: _App(
          dark: dark,
          home: const Scaffold(
            body: Column(
              children: [
                _Title(),
                Expanded(child: AuthGateScreen()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('choosing ગુજરાતી before sign-in switches the language', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Language'), findsOneWidget);
    expect(find.byKey(const Key('auth.language.en')), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth.language.gu')));
    await tester.pumpAndSettle();

    expect(find.text('ભાષા'), findsOneWidget);
    expect(prefs.getString(languageStorageKey), 'gu');

    await tester.tap(find.byKey(const Key('auth.language.en')));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('switching keeps screen state and works from initState', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const _App(
          home: Scaffold(
            body: Column(
              children: [
                _Stateful(),
                LanguageSwitch(keyPrefix: 'test.language'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('test.stateful')));
    await tester.pump();
    expect(find.text('1 Language'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test.language.gu')));
    await tester.pumpAndSettle();
    expect(find.text('1 ભાષા'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without Localizations, strings fall back to English', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: _Title()),
    );
    expect(find.text('Language'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('the sign-in screen in Gujarati fits 320 px at 200% text '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await tester.runAsync(
        () => const AssetFontLoader().load(
          'NotoSansGujarati',
          gujaratiFontAssets,
        ),
      );
      prefs.setString(languageStorageKey, 'gu');
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 900));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(tester, dark: dark);

      expect(find.text('ભાષા'), findsOneWidget);
      expect(find.text('ગુજરાતી'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
