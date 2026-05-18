import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/event_tile.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/core/widgets/progress_ring.dart';
import 'package:crewpoint_app/app/core/widgets/screen_header.dart';
import 'package:crewpoint_app/app/core/widgets/segmented_filter_bar.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

enum _Pill { all, todo, doing, done }

/// Sanity check: new design-system widgets remain usable when the OS
/// text scaler is cranked to 200% (the "any age" floor in the spec).
/// We assert no overflow exceptions thrown during layout, which is the
/// hardest failure mode to discover later.
void main() {
  Future<void> pumpScaled(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SafeArea(child: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('ProgressRing survives TextScaler 2.0', (tester) async {
    await pumpScaled(tester, const ProgressRing(todo: 5, doing: 2, done: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ScreenHeader survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const ScreenHeader(
        title: 'Good morning, Alex 👋',
        subtitle: 'Wednesday, December 11',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('EventTile survives TextScaler 2.0', (tester) async {
    final event = EventModel(
      id: 'evt-a',
      title: 'Tahoe Ski Trip — Long enough title to push the layout',
      creatorId: 'me',
      eventType: EventType.trip,
      memberIds: const ['me', 'bo', 'sk'],
      startDate: DateTime(2026, 12, 12),
      endDate: DateTime(2026, 12, 15),
    );
    await pumpScaled(
      tester,
      EventTile(event: event, todo: 2, doing: 1, done: 3),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('MoneyText survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const MoneyText(
        amount: 1234.56,
        currencyCode: 'USD',
        sign: MoneySign.owedToYou,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SegmentedFilterBar survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      SegmentedFilterBar<_Pill>(
        selected: _Pill.all,
        segments: const [
          SegmentedFilterSegment(value: _Pill.all, label: 'All'),
          SegmentedFilterSegment(value: _Pill.todo, label: 'To Do'),
          SegmentedFilterSegment(value: _Pill.doing, label: 'Doing'),
          SegmentedFilterSegment(value: _Pill.done, label: 'Done'),
        ],
        onChanged: (_) {},
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
