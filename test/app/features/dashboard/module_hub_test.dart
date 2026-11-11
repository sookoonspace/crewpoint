import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 22 and 78b: the event screen has one entry per enabled module.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    Map<String, bool> modules = EventModel.defaultModules,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue('member')],
        child: MaterialApp(
          home: EventDashboardScreen(
            event: EventModel(
              id: 'e',
              title: 'Hub',
              creatorId: 'owner',
              memberIds: const ['owner', 'member'],
              modules: modules,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final chat = find.byKey(const Key('events.hub.chat'));
  final budget = find.byKey(const Key('events.hub.budget'));
  final tasks = find.byKey(const Key('events.hub.tasks'));
  final schedule = find.byKey(const Key('events.hub.schedule'));
  final agenda = find.byKey(const Key('events.hub.agenda'));

  testWidgets('shows one entry per module, as a list at 375 px', (
    tester,
  ) async {
    await pump(tester, width: 375);
    expect(chat, findsOneWidget);
    expect(budget, findsOneWidget);
    expect(tasks, findsOneWidget);
    // Every member reads the schedule (Req 48).
    expect(schedule, findsOneWidget);
    expect(agenda, findsOneWidget);
    expect(find.byKey(const Key('events.hub.list')), findsOneWidget);
    expect(find.byKey(const Key('events.hub.grid')), findsNothing);
  });

  testWidgets('becomes a grid from 840 px', (tester) async {
    await pump(tester, width: 840);
    expect(find.byKey(const Key('events.hub.grid')), findsOneWidget);
    expect(tester.getTopLeft(chat).dy, tester.getTopLeft(budget).dy);
  });

  testWidgets('leaves out a module that is off', (tester) async {
    await pump(tester, width: 375, modules: const {'budget': false});
    expect(chat, findsOneWidget);
    expect(budget, findsNothing);
    expect(tasks, findsOneWidget);
    await pump(tester, width: 375, modules: const {'schedule': false});
    expect(schedule, findsNothing);
    expect(agenda, findsNothing);
  });

  testWidgets('explains when everything is off', (tester) async {
    await pump(
      tester,
      width: 375,
      modules: const {
        'chat': false,
        'budget': false,
        'tasks': false,
        'schedule': false,
      },
    );
    expect(find.byKey(const Key('events.hub.empty')), findsOneWidget);
  });
}
