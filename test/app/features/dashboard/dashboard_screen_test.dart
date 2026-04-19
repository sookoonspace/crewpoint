import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('shows empty state when no events', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DashboardScreen(events: [])),
    );

    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('shows event cards when events exist', (tester) async {
    final events = [
      EventModel(
        id: '1',
        title: 'Team Meetup',
        creatorId: 'u1',
        startDate: DateTime(2026, 6, 1),
      ),
      EventModel(
        id: '2',
        title: 'Launch Party',
        creatorId: 'u1',
        startDate: DateTime(2026, 7, 1),
      ),
    ];

    await tester.pumpWidget(MaterialApp(home: DashboardScreen(events: events)));

    expect(find.text('Team Meetup'), findsOneWidget);
    expect(find.text('Launch Party'), findsOneWidget);
  });
}
