import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';
import '../../../harness/event_home_overrides.dart';

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
      overrides: [
        currentUserIdProvider.overrideWithValue(_event.creatorId),
        ...eventHomeOverrides(),
      ],
      child: const MaterialApp(home: EventDashboardScreen(event: _event)),
    ),
  );
  await tester.pump();
}

void main() {
  final upNext = find.byKey(const Key('events.dashboard.upNext'));
  final openTasks = find.byKey(const Key('events.dashboard.openTasks'));

  testWidgets('from 840 px, a grid at most 960 wide with Up next and open '
      'tasks side by side', (tester) async {
    await _pumpAt(tester, const Size(1280, 800));

    final width = tester.getSize(find.byKey(_bodyKey)).width;
    expect(width, lessThanOrEqualTo(960));
    expect(tester.getTopLeft(upNext).dy, tester.getTopLeft(openTasks).dy);
    expect(
      tester.getTopLeft(upNext).dx,
      lessThan(tester.getTopLeft(openTasks).dx),
    );
  });

  testWidgets('on a phone, open tasks sit below Up next', (tester) async {
    await _pumpAt(tester, const Size(375, 2400));

    expect(
      tester.getTopLeft(openTasks).dy,
      greaterThan(tester.getBottomLeft(upNext).dy),
    );
  });

  testWidgets('body fills viewport on phone width', (tester) async {
    await _pumpAt(tester, const Size(375, 812));

    final width = tester.getSize(find.byKey(_bodyKey)).width;
    expect(width, greaterThan(300));
    expect(width, lessThanOrEqualTo(375));
  });
}
