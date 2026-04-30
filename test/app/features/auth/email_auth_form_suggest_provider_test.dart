import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart' show authProvider;
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/email_auth_form.dart';

import 'fake_auth_service.dart';

Future<void> _pumpForm(
  WidgetTester tester, {
  required FakeAuthService fake,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          () => AuthNotifier(authRepository: AuthRepository(authService: fake)),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: EmailAuthForm())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _attemptSignIn(WidgetTester tester) async {
  final auth = AppStrings.fallbackEnglish.auth;
  final emailField = find.widgetWithText(TextField, auth.emailHint);
  final passwordField = find.widgetWithText(TextField, auth.passwordHint);
  await tester.enterText(emailField, 'shared@example.com');
  await tester.enterText(passwordField, 'wrong-password-1234');
  await tester.tap(find.widgetWithText(ElevatedButton, auth.signIn));
  await tester.pump(); // start the future
  await tester.pump(); // settle the post-failure state transition
}

void main() {
  late FakeAuthService fake;

  setUp(() {
    fake = FakeAuthService();
  });

  tearDown(() {
    fake.dispose();
  });

  // Source generic-failure copy from `AppStrings.fallbackEnglish.errors`
  // so this assertion stays green when those messages are translated.
  final wrongPassword = AppStrings.fallbackEnglish.errors.wrongPassword;

  testWidgets(
    'shows the apple-suggest snackbar when password fails on an Apple-only '
    'account',
    (tester) async {
      fake.nextResult = AuthResultFailure(wrongPassword);
      fake.nextSignInMethods = const ['apple.com'];

      await _pumpForm(tester, fake: fake);
      await _attemptSignIn(tester);

      expect(
        find.byKey(const Key('auth.suggestProvider.apple')),
        findsOneWidget,
      );
      expect(find.textContaining('Apple'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets('shows the google-suggest snackbar for google-only accounts', (
    tester,
  ) async {
    fake.nextResult = AuthResultFailure(wrongPassword);
    fake.nextSignInMethods = const ['google.com'];

    await _pumpForm(tester, fake: fake);
    await _attemptSignIn(tester);

    expect(
      find.byKey(const Key('auth.suggestProvider.google')),
      findsOneWidget,
    );
  });

  testWidgets(
    'falls back to the generic snackbar when methods are empty (enumeration '
    'protection on)',
    (tester) async {
      fake.nextResult = AuthResultFailure(wrongPassword);
      fake.nextSignInMethods = const [];

      await _pumpForm(tester, fake: fake);
      await _attemptSignIn(tester);

      expect(find.byKey(const Key('auth.suggestProvider.apple')), findsNothing);
      expect(
        find.byKey(const Key('auth.suggestProvider.google')),
        findsNothing,
      );
      expect(find.text(wrongPassword), findsAtLeastNWidgets(1));
    },
  );
}
