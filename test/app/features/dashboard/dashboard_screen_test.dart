import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('shows empty state when no events', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pump();

    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Join with Code'), findsOneWidget);
  });

  testWidgets('shows join event action in app bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pump();

    // Icon appears in both app bar and empty state "Join with Code" button
    expect(find.byIcon(Icons.login_rounded), findsWidgets);
  });
}
