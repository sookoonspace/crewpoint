import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';

void main() {
  const event = EventModel(
    id: 'evt-1',
    title: 'Tahoe Trip',
    creatorId: 'owner-1',
    adminIds: ['owner-1'],
    memberIds: ['owner-1', 'member-2'],
  );

  Future<void> pumpWith(WidgetTester tester, String uid) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue(uid)],
        child: const MaterialApp(home: EventDashboardScreen(event: event)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('owner sees the Delete Event tile and NOT the Leave Event tile', (
    tester,
  ) async {
    await pumpWith(tester, 'owner-1');

    expect(find.text('Delete Event'), findsOneWidget);
    expect(find.text('Leave Event'), findsNothing);
  });

  testWidgets(
    'non-owner member sees the Leave Event tile and NOT the Delete Event tile',
    (tester) async {
      await pumpWith(tester, 'member-2');

      expect(find.text('Leave Event'), findsOneWidget);
      expect(find.text('Delete Event'), findsNothing);
    },
  );
}
