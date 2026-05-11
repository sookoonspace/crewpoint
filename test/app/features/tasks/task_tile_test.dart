import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, child: child)),
  );

  TaskModel buildTask(TaskStatus status) => TaskModel(
    id: 'task-1',
    eventId: 'evt-1',
    title: 'Buy snacks',
    status: status,
  );

  Color stripeColor(WidgetTester tester) {
    final stripe = tester.widget<Container>(
      find.byKey(const Key('tasks.tile.task-1.stripe')),
    );
    final decoration = stripe.decoration as BoxDecoration?;
    return decoration?.color ?? (stripe.color ?? const Color(0x00000000));
  }

  testWidgets('stripe color matches status — todo → lightGrey', (tester) async {
    await tester.pumpWidget(
      harness(
        TaskTile(task: buildTask(TaskStatus.todo), canChangeStatus: false),
      ),
    );
    expect(stripeColor(tester), AppColors.lightGrey);
  });

  testWidgets('stripe color matches status — inProgress → sage', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        TaskTile(
          task: buildTask(TaskStatus.inProgress),
          canChangeStatus: false,
        ),
      ),
    );
    expect(stripeColor(tester), AppColors.sage);
  });

  testWidgets('stripe color matches status — done → sageDark', (tester) async {
    await tester.pumpWidget(
      harness(
        TaskTile(task: buildTask(TaskStatus.done), canChangeStatus: false),
      ),
    );
    expect(stripeColor(tester), AppColors.sageDark);
  });
}
