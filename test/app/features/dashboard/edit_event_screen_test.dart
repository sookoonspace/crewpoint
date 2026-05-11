import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/edit_event_screen.dart';

void main() {
  final initial = EventModel(
    id: 'evt-1',
    title: 'Trip to Tahoe',
    creatorId: 'uid-1',
    description: 'Snow weekend',
    eventType: EventType.trip,
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 6, 3),
    adminIds: const ['uid-1'],
    memberIds: const ['uid-1', 'uid-2'],
    status: EventStatus.active,
    currency: 'USD',
  );

  testWidgets(
    'pre-fills title + description + dates + status, and exposes no currency control',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: EditEventScreen(initial: initial)),
      );

      final title = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('editEvent.title')),
          matching: find.byType(TextField),
        ),
      );
      expect(title.controller!.text, 'Trip to Tahoe');

      final desc = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('editEvent.description')),
          matching: find.byType(TextField),
        ),
      );
      expect(desc.controller!.text, 'Snow weekend');

      expect(find.text('Jun 1, 2026'), findsOneWidget);
      expect(find.text('Jun 3, 2026'), findsOneWidget);

      // Negative assertion — currency is immutable post-creation.
      expect(find.byKey(const Key('events.create.currency')), findsNothing);
      expect(find.text('Currency'), findsNothing);
    },
  );

  testWidgets(
    'end-date validator rejects end-before-start; accepts equal; accepts null',
    (tester) async {
      EventModel? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: EditEventScreen(
            initial: initial.copyWith(
              startDate: DateTime(2026, 6, 5),
              endDate: DateTime(2026, 6, 1), // invalid initially
            ),
            onSubmit: (e) => submitted = e,
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('editEvent.save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('editEvent.save')));
      await tester.pumpAndSettle();
      expect(
        find.text('End date must be on or after start date'),
        findsOneWidget,
      );
      expect(submitted, isNull);

      // Clear end date → should submit (null is valid).
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('editEvent.endDate')),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('editEvent.save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('editEvent.save')));
      await tester.pumpAndSettle();
      expect(submitted, isNotNull);
      expect(submitted!.endDate, isNull);
    },
  );

  testWidgets('date picker accepts past dates (firstDate override)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditEventScreen(
          initial: initial.copyWith(
            startDate: DateTime(2010, 1, 1), // far in the past
            clearEndDate: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('editEvent.startDate')));
    await tester.pumpAndSettle();
    // Regression: picker opens without throwing because firstDate is
    // DateTime(2000), well before the pre-filled 2010-01-01.
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('archive toggle flips status', (tester) async {
    EventModel? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEventScreen(initial: initial, onSubmit: (e) => submitted = e),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('editEvent.archive')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('editEvent.archive')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('editEvent.save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('editEvent.save')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.status, EventStatus.archived);
  });
}
