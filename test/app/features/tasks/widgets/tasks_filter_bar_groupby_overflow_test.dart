/// Pins the iPhone 12 mini regression spotted in the 2026-06-08 UI QA
/// pass: at the device's 375 px portrait viewport the SegmentedButton
/// labels overflowed once the selected segment gained its check icon —
/// "Assignee" wrapped to "Assign\nee" and "Due window" stacked. This
/// test renders the bar inside a 375 px-wide `SizedBox` (the width the
/// Wrap layout sees in production once the sort menu eats its share)
/// and asserts the SegmentedButton's overall height stays at the
/// single-row Material tap-target height — when any label wraps the
/// segment grows and the bar's height jumps.
///
/// The selection moves with `TasksGroupBy`, so we cycle through all
/// three values to catch a label that only wraps when it's *another*
/// segment being compressed by the checkmark.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_filter_bar.dart';

void main() {
  // The Wrap row hosting the sort menu + SegmentedButton sees ~375 px
  // on iPhone 12 mini portrait. SafeArea + the parent column padding
  // already factor out of the harness here.
  const iphone12MiniWidth = 375.0;

  // Material's default SegmentedButton renders at ~40 px tall with a
  // single-line label. A second wrapped line pushes it past 50 px on
  // the test renderer; 50 splits the two cleanly without coupling the
  // assertion to the exact font metric.
  const singleRowHeightCap = 50.0;

  testWidgets('group-by SegmentedButton stays single-row at 375 px viewport '
      'for every selected segment', (tester) async {
    for (final group in TasksGroupBy.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SizedBox(
                width: iphone12MiniWidth,
                child: TasksFilterBar(
                  filter: TasksFilter(groupBy: group),
                  onFilterChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Layout itself must not throw — wrapping isn't an exception,
      // but any RenderFlex / SegmentedButton constraint violation
      // would surface here.
      expect(tester.takeException(), isNull, reason: 'group=$group');

      final segmentedHeight = tester
          .getSize(find.byKey(const Key('tasks.list.groupToggle')))
          .height;
      expect(
        segmentedHeight,
        lessThan(singleRowHeightCap),
        reason:
            'SegmentedButton grew taller than a single row at '
            '$iphone12MiniWidth px when "$group" was selected '
            '(height=$segmentedHeight). A segment label likely wrapped.',
      );
    }
  });
}
