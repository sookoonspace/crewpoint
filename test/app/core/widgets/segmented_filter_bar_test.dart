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

  testWidgets(
    'default layout uses SingleChildScrollView (no Expanded inside the bar)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(
        tester,
        SegmentedFilterBar<_TaskFilter>(
          key: const Key('seg.bar.default'),
          selected: _TaskFilter.all,
          segments: const [
            SegmentedFilterSegment(
              value: _TaskFilter.all,
              label: 'All',
              keyValue: Key('seg.all'),
            ),
            SegmentedFilterSegment(
              value: _TaskFilter.todo,
              label: 'To Do',
              keyValue: Key('seg.todo'),
            ),
            SegmentedFilterSegment(
              value: _TaskFilter.doing,
              label: 'Doing',
              keyValue: Key('seg.doing'),
            ),
            SegmentedFilterSegment(
              value: _TaskFilter.done,
              label: 'Done',
              keyValue: Key('seg.done'),
            ),
          ],
          onChanged: (_) {},
        ),
      );

      final bar = find.byKey(const Key('seg.bar.default'));
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byType(SingleChildScrollView)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(Expanded)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'equalWidth=true happy path: short labels at 360 px use Expanded, no scroll',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(
        tester,
        SegmentedFilterBar<_Pill>(
          key: const Key('seg.bar.equalWidth'),
          selected: _Pill.upcoming,
          equalWidth: true,
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

      final bar = find.byKey(const Key('seg.bar.equalWidth'));
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byType(Expanded)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: bar, matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'equalWidth=true overflow fallback: long labels at 320 px scroll, no crush',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(
        tester,
        SegmentedFilterBar<_TaskFilter>(
          key: const Key('seg.bar.equalWidth.fallback'),
          selected: _TaskFilter.all,
          equalWidth: true,
          segments: const [
            SegmentedFilterSegment(
              value: _TaskFilter.all,
              label: 'Absolutely Everything',
              keyValue: Key('seg.all'),
            ),
            SegmentedFilterSegment(
              value: _TaskFilter.todo,
              label: 'Things To Get Done',
              keyValue: Key('seg.todo'),
            ),
            SegmentedFilterSegment(
              value: _TaskFilter.doing,
              label: 'Currently In Progress',
              keyValue: Key('seg.doing'),
            ),
            SegmentedFilterSegment(
              value: _TaskFilter.done,
              label: 'Already Completed',
              keyValue: Key('seg.done'),
            ),
          ],
          onChanged: (_) {},
        ),
      );

      final bar = find.byKey(const Key('seg.bar.equalWidth.fallback'));
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byType(Expanded)),
        findsNothing,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(SingleChildScrollView)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'equalWidth=true centres each label horizontally inside its pill — '
    'fix for the 2026-06-11 iPhone 12 mini home dashboard QA note where '
    'Upcoming/Past labels visually drifted toward the left edge',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentedFilterBar<_Pill>(
              selected: _Pill.upcoming,
              equalWidth: true,
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
          ),
        ),
      );

      for (final entry in const [
        (Key('seg.upcoming'), 'Upcoming'),
        (Key('seg.past'), 'Past'),
      ]) {
        final pillCentre = tester.getCenter(find.byKey(entry.$1));
        final labelCentre = tester.getCenter(find.text(entry.$2));
        expect(
          (labelCentre.dx - pillCentre.dx).abs(),
          lessThan(1.0),
          reason:
              'Label "${entry.$2}" off-centre by '
              '${(labelCentre.dx - pillCentre.dx).abs()} px (pill.dx='
              '${pillCentre.dx}, label.dx=${labelCentre.dx}).',
        );
      }
    },
  );
}

enum _TaskFilter { all, todo, doing, done }
