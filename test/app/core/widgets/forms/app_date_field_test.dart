import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_date_field.dart';

void main() {
  testWidgets(
    'modal path: width < Breakpoints.compactMax opens showDatePicker on tap',
    (tester) async {
      // Narrow viewport — below the 600 px compact/medium boundary.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DateTime? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDateField(
              labelText: 'Due Date',
              value: null,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );

      // Sanity: the trigger row renders, the inline calendar does not.
      expect(find.text('Due Date'), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsNothing);

      // Tap the trigger → modal date picker opens.
      await tester.tap(find.byKey(const Key('forms.date.trigger')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Cancel — no value captured.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(captured, isNull);
    },
  );

  testWidgets(
    'inline path: width >= Breakpoints.compactMax renders CalendarDatePicker',
    (tester) async {
      // Wide viewport — desktop-class width.
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DateTime? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDateField(
              labelText: 'Due Date',
              value: DateTime(2026, 6, 15),
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );

      // Inline calendar is rendered without any tap.
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      // Modal trigger is absent on wide viewports.
      expect(find.byKey(const Key('forms.date.trigger')), findsNothing);

      // No assertion on tapping a day — Flutter's CalendarDatePicker
      // exposes day cells via gridview internals which are fragile to
      // match in widget tests. The presence of the picker itself
      // proves the responsive path engaged. We expose captured for
      // future tests that need it.
      expect(captured, isNull);
    },
  );

  testWidgets('clearable: clear icon emits onChanged(null)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DateTime? captured = DateTime(2026, 6, 15);
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDateField(
            value: captured,
            onChanged: (v) {
              changed = true;
              captured = v;
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('forms.date.clear')), findsOneWidget);
    await tester.tap(find.byKey(const Key('forms.date.clear')));
    await tester.pump();
    expect(changed, isTrue);
    expect(captured, isNull);
  });
}
