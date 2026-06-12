/// Pins the admin-discoverable "Edit Event" body tile from the
/// 2026-06-11 iPhone 12 mini QA pass. The pre-existing top-right
/// gear icon is admin-only and easy to miss; this body tile gives
/// admins an explicit, labelled entry point above the existing
/// `Invite Members` tile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';

const _ownerEvent = EventModel(
  id: 'evt-1',
  title: 'Weekend getaway',
  creatorId: 'owner-uid',
  memberIds: ['owner-uid', 'member-uid'],
);

Future<void> _pump(
  WidgetTester tester, {
  required String? currentUid,
  required EventModel event,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserIdProvider.overrideWith((ref) => currentUid)],
      child: MaterialApp(home: EventDashboardScreen(event: event)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('admin sees the Edit Event tile under the Members preview', (
    tester,
  ) async {
    // creatorId is treated as admin/owner by EventModel.isAdmin.
    await _pump(tester, currentUid: 'owner-uid', event: _ownerEvent);

    expect(
      find.byKey(const Key('eventDashboard.editEvent.tile')),
      findsOneWidget,
    );
    expect(find.text('Edit Event'), findsOneWidget);
  });

  testWidgets('non-admin viewer does NOT see the Edit Event tile', (
    tester,
  ) async {
    await _pump(tester, currentUid: 'member-uid', event: _ownerEvent);

    expect(
      find.byKey(const Key('eventDashboard.editEvent.tile')),
      findsNothing,
    );
  });

  testWidgets(
    'unauthenticated (null uid) viewer does NOT see the Edit Event tile',
    (tester) async {
      await _pump(tester, currentUid: null, event: _ownerEvent);

      expect(
        find.byKey(const Key('eventDashboard.editEvent.tile')),
        findsNothing,
      );
    },
  );
}
