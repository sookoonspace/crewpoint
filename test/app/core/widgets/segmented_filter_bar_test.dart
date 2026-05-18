import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/segmented_filter_bar.dart';

enum _Pill { upcoming, past }

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('renders one pill per segment', (tester) async {
    await pump(
      tester,
      SegmentedFilterBar<_Pill>(
        selected: _Pill.upcoming,
        segments: const [
          SegmentedFilterSegment(
            value: _Pill.upcoming,
            label: 'Upcoming',
            keyValue: Key('seg.upcoming'),
          ),
          SegmentedFilterSegment(
            value: _Pill.past,
            label: 'Past',
            keyValue: Key('seg.past'),
          ),
        ],
        onChanged: (_) {},
      ),
    );

    expect(find.byKey(const Key('seg.upcoming')), findsOneWidget);
    expect(find.byKey(const Key('seg.past')), findsOneWidget);
  });

  testWidgets('tapping a non-active pill fires onChanged with its value', (
    tester,
  ) async {
    _Pill? selected;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SegmentedFilterBar<_Pill>(
          selected: selected ?? _Pill.upcoming,
          segments: const [
            SegmentedFilterSegment(
              value: _Pill.upcoming,
              label: 'Upcoming',
              keyValue: Key('seg.upcoming'),
            ),
            SegmentedFilterSegment(
              value: _Pill.past,
              label: 'Past',
              keyValue: Key('seg.past'),
            ),
          ],
          onChanged: (next) => setState(() => selected = next),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('seg.past')));
    await tester.pump();
    expect(selected, _Pill.past);
  });

  testWidgets('tapping the already-active pill is a no-op', (tester) async {
    var changes = 0;
    await pump(
      tester,
      SegmentedFilterBar<_Pill>(
        selected: _Pill.upcoming,
        segments: const [
          SegmentedFilterSegment(
            value: _Pill.upcoming,
            label: 'Upcoming',
            keyValue: Key('seg.upcoming'),
          ),
          SegmentedFilterSegment(
            value: _Pill.past,
            label: 'Past',
            keyValue: Key('seg.past'),
          ),
        ],
        onChanged: (_) => changes++,
      ),
    );

    await tester.tap(find.byKey(const Key('seg.upcoming')));
    await tester.pump();
    expect(changes, 0);
  });

  testWidgets('renders a count badge when provided', (tester) async {
    await pump(
      tester,
      SegmentedFilterBar<_Pill>(
        selected: _Pill.upcoming,
        segments: const [
          SegmentedFilterSegment(
            value: _Pill.upcoming,
            label: 'Upcoming',
            keyValue: Key('seg.upcoming'),
            count: 3,
          ),
          SegmentedFilterSegment(
            value: _Pill.past,
            label: 'Past',
            keyValue: Key('seg.past'),
          ),
        ],
        onChanged: (_) {},
      ),
    );

    expect(find.text('3'), findsOneWidget);
  });
}
