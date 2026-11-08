import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../harness/tasks_harness.dart';

/// #68 (Req 72, H-02): tasks belong to an optional crew, shown and
/// filterable when crews are in use, keeping the overdue filter.
void main() {
  const user = AppUser(uid: 'owner-1', email: 'owner@example.com');
  const event = EventModel(
    id: 'evt-1',
    title: 'Convention',
    creatorId: 'owner-1',
    memberIds: ['owner-1'],
  );

  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TasksHarness> open(WidgetTester tester, {bool crews = true}) async {
    tester.view.physicalSize = const Size(375, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = TasksHarness(event: event, currentUser: user);
    addTearDown(() async => harness.database.close());
    await harness.seed();
    final db = harness.firestore;
    if (crews) {
      await db.doc('events/evt-1/crews/food').set({'name': 'Food'});
      await db.doc('events/evt-1/crews/program').set({'name': 'Program'});
    }
    Future<void> task(String id, String title, String? crewId, DateTime due) =>
        db.doc('events/evt-1/tasks/$id').set({
          'eventId': 'evt-1',
          'title': title,
          'createdBy': 'owner-1',
          'status': 'todo',
          'crewId': crewId,
          'dueDate': Timestamp.fromDate(due),
        });
    await task('a', 'Confirm caterer', 'food', DateTime(2026, 6, 1));
    await task('b', 'Order snacks', 'food', DateTime(2026, 7, 1));
    await task('c', 'Book DJ', 'program', DateTime(2026, 6, 1));
    await task('d', 'Print badges', null, DateTime(2026, 6, 1));
    await tester.pumpWidget(harness.buildApp());
    await pumpFrames(tester);
    return harness;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('H-02 crews show on tasks, filter with overdue, and group', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 6, 15, 12)), () async {
      await open(tester);

      expect(find.byKey(const Key('tasks.tile.a.crew')), findsOneWidget);
      expect(find.byKey(const Key('tasks.tile.d.crew')), findsNothing);

      // Food's tasks only.
      await tester.tap(find.byKey(const Key('tasks.list.crewFilter')));
      await pumpFrames(tester);
      await tester.tap(find.byKey(const Key('tasks.list.crewFilter.food')));
      await pumpFrames(tester);
      expect(find.text('Confirm caterer'), findsOneWidget);
      expect(find.text('Order snacks'), findsOneWidget);
      expect(find.text('Book DJ'), findsNothing);

      // With overdue too: only Food's overdue task.
      await tester.tap(find.byKey(const Key('tasks.list.filterChip.overdue')));
      await pumpFrames(tester);
      expect(find.text('Confirm caterer'), findsOneWidget);
      expect(find.text('Order snacks'), findsNothing);

      // Back to every crew, grouped by crew.
      await tester.tap(find.byKey(const Key('tasks.list.filterChip.overdue')));
      await tester.tap(find.byKey(const Key('tasks.list.crewFilter')));
      await pumpFrames(tester);
      await tester.tap(find.byKey(const Key('tasks.list.crewFilter.all')));
      await pumpFrames(tester);
      await tester.tap(find.byKey(const Key('tasks.list.groupToggle.crew')));
      await pumpFrames(tester);
      for (final key in ['food', 'program', 'noCrew']) {
        expect(
          find.byKey(Key('tasks.list.groupHeader.$key')),
          findsOneWidget,
          reason: key,
        );
      }
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  });

  testWidgets('a new task can be given a crew', (tester) async {
    final harness = await open(tester);
    await tester.tap(find.byKey(const Key('tasks.list.create')));
    await tester.pump(const Duration(milliseconds: 600));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('tasks.create.title')),
        matching: find.byType(EditableText),
      ),
      'Hire stage crew',
    );
    await tester.ensureVisible(find.byKey(const Key('tasks.create.crew')));
    await tester.tap(find.byKey(const Key('tasks.create.crew')));
    await pumpFrames(tester);
    await tester.tap(find.text('Program').last);
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const Key('tasks.create.save')));
    await tester.tap(find.byKey(const Key('tasks.create.save')));
    await tester.pump(const Duration(milliseconds: 600));
    await pumpFrames(tester);

    final saved = await harness.firestore
        .collection('events/evt-1/tasks')
        .where('title', isEqualTo: 'Hire stage crew')
        .get();
    expect(saved.docs.single.data()['crewId'], 'program');
    await finish(tester);
  });

  testWidgets('with no crews, nothing about crews shows', (tester) async {
    await open(tester, crews: false);
    expect(find.byKey(const Key('tasks.list.crewFilter')), findsNothing);
    expect(find.byKey(const Key('tasks.list.groupToggle.crew')), findsNothing);
    expect(find.byKey(const Key('tasks.tile.a.crew')), findsNothing);
    await tester.tap(find.byKey(const Key('tasks.list.create')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('tasks.create.crew')), findsNothing);
    await finish(tester);
  });
}
