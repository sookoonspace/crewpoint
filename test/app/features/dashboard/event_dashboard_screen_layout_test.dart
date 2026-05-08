import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';

const _bodyKey = Key('eventDashboard.body.clamped');

const _event = EventModel(
  id: 'e1',
  title: 'Trip',
  creatorId: 'owner',
  adminIds: ['owner'],
  memberIds: ['owner'],
);

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserIdProvider.overrideWithValue(_event.creatorId)],
      child: const MaterialApp(home: EventDashboardScreen(event: _event)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'clamps SliverList subtree to <= 960 while hero stays full-bleed at desktop',
    (tester) async {
      await _pumpAt(tester, const Size(1280, 800));

      final width = tester.getSize(find.byKey(_bodyKey)).width;
      expect(width, lessThanOrEqualTo(960));

      // Hero (the gradient Container ancestor of the title) spans viewport.
      final heroAncestor = find.ancestor(
        of: find.text('Trip'),
        matching: find.byType(Container),
      );
      final heroWidth = tester.getSize(heroAncestor.first).width;
      expect(heroWidth, equals(1280));
    },
  );

  testWidgets('body fills viewport on phone width', (tester) async {
    await _pumpAt(tester, const Size(375, 812));

    final width = tester.getSize(find.byKey(_bodyKey)).width;
    expect(width, greaterThan(300));
    expect(width, lessThanOrEqualTo(375));
  });
}
