import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/event_tile.dart';
import 'package:crewpoint_app/app/core/widgets/progress_ring.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  final event = EventModel(
    id: 'evt-1',
    title: 'Tahoe Ski Trip',
    creatorId: 'me',
    eventType: EventType.trip,
    memberIds: const ['me', 'bo', 'sk'],
    startDate: DateTime(2026, 12, 12),
    endDate: DateTime(2026, 12, 15),
  );

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('renders icon, title, member count badge, and ring label', (
    tester,
  ) async {
    await pump(tester, EventTile(event: event, todo: 2, doing: 1, done: 3));

    // Icon derived from EventType.trip.
    expect(find.byIcon(Icons.luggage_outlined), findsOneWidget);
    // Title.
    expect(find.text('Tahoe Ski Trip'), findsOneWidget);
    // Member count badge (3 ids → "3 members").
    expect(find.text('3 members'), findsOneWidget);
    // Progress ring with provided counts.
    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.text('3/6'), findsOneWidget);
  });

  testWidgets('singular "1 member" when memberIds has one entry', (
    tester,
  ) async {
    const solo = EventModel(
      id: 'evt-2',
      title: 'Solo Trip',
      creatorId: 'me',
      memberIds: ['me'],
    );
    await pump(
      tester,
      const EventTile(event: solo, todo: 0, doing: 0, done: 0),
    );
    expect(find.text('1 member'), findsOneWidget);
  });

  testWidgets('tile fires onTap when pressed', (tester) async {
    var taps = 0;
    await pump(
      tester,
      EventTile(event: event, todo: 0, doing: 0, done: 0, onTap: () => taps++),
    );
    await tester.tap(find.byType(EventTile));
    expect(taps, 1);
  });
}
