import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';

import '../../../app/features/auth/fake_auth_service.dart';

Widget _wrapWithProviders(GoRouter router) {
  final fakeAuthService = FakeAuthService();
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(
        () => AuthNotifier(
          authRepository: AuthRepository(authService: fakeAuthService),
        ),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('redirects unauthenticated user to auth gate', (tester) async {
    final router = createRouter(
      isOnboardingComplete: true,
      isAuthenticated: false,
    );

    await tester.pumpWidget(_wrapWithProviders(router));
    await tester.pumpAndSettle();

    expect(find.text('CrewPoint'), findsOneWidget);
  });

  testWidgets('redirects authenticated user past auth to dashboard', (
    tester,
  ) async {
    final router = createRouter(
      isOnboardingComplete: true,
      isAuthenticated: true,
    );

    await tester.pumpWidget(_wrapWithProviders(router));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('redirects to onboarding when not complete', (tester) async {
    final router = createRouter(
      isOnboardingComplete: false,
      isAuthenticated: false,
    );

    await tester.pumpWidget(_wrapWithProviders(router));
    await tester.pumpAndSettle();

    expect(find.text('CrewPoint'), findsOneWidget);
  });
}
