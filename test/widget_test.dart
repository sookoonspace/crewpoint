import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';

void main() {
  testWidgets('App renders auth gate when unauthenticated', (tester) async {
    final router = createRouter(
      isOnboardingComplete: true,
      isAuthenticated: false,
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    // Auth gate shows CrewPoint header
    expect(find.text('CrewPoint'), findsOneWidget);
  });
}
