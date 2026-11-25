import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/registration/domain/public_event.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';
import 'package:crewpoint_app/l10n/gen/app_localizations.dart';

import '../app/features/auth/fake_auth_service.dart';
import 'fake_member_calls.dart';
import 'fake_qr.dart';

/// The real router over fake auth, calls and device storage, for the light
/// sign-in (#241). [auth] backs both the auth state and the sign-in calls.
class SignInHarness {
  SignInHarness({this.onboarded = true, AuthUser? signedInAs}) {
    if (signedInAs != null) auth.setCurrentUser(signedInAs);
  }

  final auth = FakeAuthService();
  final calls = FakeMemberCalls();
  bool onboarded;
  late SharedPreferences prefs;
  late GoRouter router;

  static const slug = 'convention-2027';

  /// An open event's page, and an invited one at `shah-wedding`.
  void seedEvents() {
    calls.eventPages[slug] = const PublicEvent(
      state: PublicEventState.open,
      slug: slug,
      title: 'Convention 2027',
      timeZone: 'America/Chicago',
      mode: RegistrationMode.open,
    );
    calls.eventPages['shah-wedding'] = const PublicEvent(
      state: PublicEventState.open,
      slug: 'shah-wedding',
      title: 'Shah wedding',
    );
  }

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> pump(
    WidgetTester tester,
    String initialLocation, {
    Map<String, Object> stored = const {},
    Locale? locale,
    bool dark = false,
    List<Override> overrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    seedEvents();
    router = createRouter(
      isOnboardingComplete: () => onboarded,
      isAuthenticated: () => auth.currentUser != null,
      initialLocation: initialLocation,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(auth),
          authProvider.overrideWith(
            () =>
                AuthNotifier(authRepository: AuthRepository(authService: auth)),
          ),
          memberCallsProvider.overrideWithValue(calls),
          qrRendererProvider.overrideWithValue(FakeQrRenderer()),
          ...overrides,
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: CpTheme.light(),
          darkTheme: CpTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: locale,
          localizationsDelegates: locale == null
              ? null
              : AppLocalizations.localizationsDelegates,
          supportedLocales: locale == null
              ? const [Locale('en', 'US')]
              : AppLocalizations.supportedLocales,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, Key key, String text) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.enterText(find.byKey(key), text);
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    auth.dispose();
  }
}
