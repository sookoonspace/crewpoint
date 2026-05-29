import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
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

  testWidgets('renders a thin sage divider below the label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TasksGroupHeader(label: 'To Do')),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.color, AppColors.sage.withValues(alpha: 0.25));
    expect(container.constraints?.maxHeight, 1.0);
  });
}
