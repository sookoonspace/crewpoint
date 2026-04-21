import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';

void main() {
  testWidgets('redirects unauthenticated user to auth gate', (tester) async {
    final router = createRouter(
      isOnboardingComplete: true,
      isAuthenticated: false,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('redirects to onboarding when not complete', (tester) async {
    final router = createRouter(
      isOnboardingComplete: false,
      isAuthenticated: false,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('CrewPoint'), findsOneWidget);
  });
}
