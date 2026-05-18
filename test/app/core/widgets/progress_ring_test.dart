import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/progress_ring.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('renders "{done}/{total}" label for non-empty counts', (
    tester,
  ) async {
    await pump(tester, const ProgressRing(todo: 5, doing: 2, done: 3));
    expect(find.text('3/10'), findsOneWidget);
  });

  testWidgets('renders "—" label and no division by zero when total is 0', (
    tester,
  ) async {
    await pump(tester, const ProgressRing(todo: 0, doing: 0, done: 0));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0/0'), findsNothing);
  });

  testWidgets('exposes status counts via semantics', (tester) async {
    await pump(tester, const ProgressRing(todo: 5, doing: 2, done: 3));
    expect(
      find.bySemanticsLabel('3 of 10 tasks done, 2 in progress, 5 to do'),
      findsOneWidget,
    );
  });
}
