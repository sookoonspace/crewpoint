import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_group_header.dart';

void main() {
  testWidgets('renders the supplied label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TasksGroupHeader(label: 'To Do')),
      ),
    );

    expect(find.text('To Do'), findsOneWidget);
  });

  testWidgets('is a section header with the group count on the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TasksGroupHeader(label: 'Overdue', count: 2)),
      ),
    );

    final header = tester.widget<CpSectionHeader>(find.byType(CpSectionHeader));
    expect(header.title, 'Overdue');
    expect(header.trailingText, '2');
    expect(find.text('2'), findsOneWidget);
  });
}
