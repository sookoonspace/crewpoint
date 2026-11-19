/// The filter bar on the narrowest phone (320 px) at 200% text (Spec #186
/// Req 45): nothing overflows for any grouping, the filter pills scroll
/// sideways instead of squeezing, and the grouping and sort stay at least
/// 48 px tall to tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_filter_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester, TasksGroupBy group) =>
      tester.pumpWidget(
        MaterialApp(
          theme: CpTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: TasksFilterBar(
                    filter: TasksFilter(groupBy: group),
                    onFilterChanged: (_) {},
                    crews: const [CrewModel(id: 'food', name: 'Food')],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('no overflow at 320 px and 200% text, whatever the grouping', (
    tester,
  ) async {
    for (final group in TasksGroupBy.values) {
      await pump(tester, group);
      expect(tester.takeException(), isNull, reason: 'group=$group');
    }
  });

  testWidgets('grouping and sort are at least 48 px tall', (tester) async {
    await pump(tester, TasksGroupBy.status);
    for (final key in [
      'tasks.list.groupToggle.status',
      'tasks.list.groupToggle.assignee',
      'tasks.list.groupToggle.dueWindow',
      'tasks.list.groupToggle.crew',
      'tasks.list.sortMenu',
    ]) {
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
  });
}
