import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';

import 'app/features/auth/fake_auth_service.dart';

void main() {
  testWidgets('App renders auth gate when unauthenticated', (tester) async {
    final fakeAuthService = FakeAuthService();
    final router = createRouter(
      isOnboardingComplete: true,
      isAuthenticated: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              authRepository: AuthRepository(authService: fakeAuthService),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Auth gate shows CrewPoint header
    expect(find.text('CrewPoint'), findsOneWidget);
  });
}
