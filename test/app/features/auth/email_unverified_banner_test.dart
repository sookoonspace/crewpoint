import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart' show authProvider;
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/email_unverified_banner.dart';

import 'fake_auth_service.dart';

const _key = Key('auth.verifyBanner');

Future<void> _pumpBanner(
  WidgetTester tester, {
  required FakeAuthService fake,
  AuthUser? signedInUser,
}) async {
  if (signedInUser != null) fake.setCurrentUser(signedInUser);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          () => AuthNotifier(authRepository: AuthRepository(authService: fake)),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: EmailUnverifiedBanner())),
    ),
  );
  // Allow the auth stream to propagate.
  await tester.pumpAndSettle();
}

void main() {
  late FakeAuthService fake;

  setUp(() {
    fake = FakeAuthService();
  });

  tearDown(() {
    fake.dispose();
  });

  testWidgets('renders nothing when the user is signed out', (tester) async {
    await _pumpBanner(tester, fake: fake);
    expect(find.byKey(_key), findsNothing);
  });

  testWidgets('renders nothing when emailVerified is true', (tester) async {
    await _pumpBanner(
      tester,
      fake: fake,
      signedInUser: const AuthUser(
        uid: 'u1',
        email: 'user@example.com',
        emailVerified: true,
        providerIds: ['password'],
      ),
    );
    expect(find.byKey(_key), findsNothing);
  });

  testWidgets('renders nothing for OAuth-linked accounts', (tester) async {
    await _pumpBanner(
      tester,
      fake: fake,
      signedInUser: const AuthUser(
        uid: 'u1',
        email: 'user@example.com',
        emailVerified: false,
        providerIds: ['password', 'apple.com'],
      ),
    );
    expect(find.byKey(_key), findsNothing);
  });

  testWidgets('renders the banner for an unverified password-only account', (
    tester,
  ) async {
    await _pumpBanner(
      tester,
      fake: fake,
      signedInUser: const AuthUser(
        uid: 'u1',
        email: 'user@example.com',
        emailVerified: false,
        providerIds: ['password'],
      ),
    );
    expect(find.byKey(_key), findsOneWidget);
    expect(find.textContaining('user@example.com'), findsOneWidget);
    expect(find.byKey(const Key('auth.verifyBanner.resend')), findsOneWidget);
    expect(find.byKey(const Key('auth.verifyBanner.refresh')), findsOneWidget);
  });

  testWidgets('tapping Resend invokes sendEmailVerification on the service', (
    tester,
  ) async {
    await _pumpBanner(
      tester,
      fake: fake,
      signedInUser: const AuthUser(
        uid: 'u1',
        email: 'user@example.com',
        emailVerified: false,
        providerIds: ['password'],
      ),
    );

    await tester.tap(find.byKey(const Key('auth.verifyBanner.resend')));
    await tester.pump();

    expect(fake.sendEmailVerificationCalls, equals(1));
  });

  testWidgets(
    'tapping "I\'ve verified" invokes reloadCurrentUser on the service',
    (tester) async {
      await _pumpBanner(
        tester,
        fake: fake,
        signedInUser: const AuthUser(
          uid: 'u1',
          email: 'user@example.com',
          emailVerified: false,
          providerIds: ['password'],
        ),
      );

      await tester.tap(find.byKey(const Key('auth.verifyBanner.refresh')));
      await tester.pump();

      expect(fake.reloadCalls, equals(1));
    },
  );
}
