import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/progress_ring.dart';
import 'package:crewpoint_app/app/core/widgets/status_badge.dart';
import 'package:crewpoint_app/app/core/widgets/task_progress_summary.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('renders one ProgressRing and three StatusBadge chips', (
    tester,
  ) async {
    await pump(tester, const TaskProgressSummary(todo: 5, doing: 2, done: 3));

    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.byType(StatusBadge), findsNWidgets(3));
    expect(find.text('3/10'), findsOneWidget);
  });

  testWidgets('compact variant hides the chip row', (tester) async {
    await pump(
      tester,
      const TaskProgressSummary(todo: 5, doing: 2, done: 3, compact: true),
    );

    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.byType(StatusBadge), findsNothing);
  });
}
