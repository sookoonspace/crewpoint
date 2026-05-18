import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/widgets/status_badge.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets(
    'todo variant uses the unchecked-circle icon and todo foreground',
    (tester) async {
      await pump(tester, const StatusBadge.todo(label: 'To Do'));
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.text('To Do'), findsOneWidget);
    },
  );

  testWidgets('doing variant uses the play-circle icon', (tester) async {
    await pump(tester, const StatusBadge.doing(label: 'Doing'));
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.text('Doing'), findsOneWidget);
  });

  testWidgets('done variant uses the check-circle icon', (tester) async {
    await pump(tester, const StatusBadge.done(label: 'Done'));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('urgent variant uses the warning icon and urgent foreground', (
    tester,
  ) async {
    await pump(tester, const StatusBadge.urgent(label: 'Urgent'));
    final icon = tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
    expect(icon.color, AppColors.statusUrgentFg);
  });

  testWidgets('info variant uses the info icon', (tester) async {
    await pump(tester, const StatusBadge.info(label: 'Info'));
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('renders trailing count when provided', (tester) async {
    await pump(tester, const StatusBadge.done(label: 'Done', count: 3));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
