import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/responsive_shell.dart';

void main() {
  Widget buildSubject({
    int currentIndex = 0,
    ValueChanged<int>? onDestinationSelected,
    VoidCallback? onSignOut,
    Widget? body,
    int tasksBadge = 0,
    int chatBadge = 0,
    int budgetBadge = 0,
  }) {
    return MaterialApp(
      home: ResponsiveShell(
        currentIndex: currentIndex,
        onDestinationSelected: onDestinationSelected ?? (_) {},
        onSignOut: onSignOut ?? () {},
        tasksBadge: tasksBadge,
        chatBadge: chatBadge,
        budgetBadge: budgetBadge,
        body: body ?? const SizedBox.shrink(),
      ),
    );
  }

  testWidgets('renders NavigationBar at 600 width', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(600, 800));
    await tester.pumpWidget(buildSubject());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('renders NavigationBar at 800 width (below 840 boundary)', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(800, 1024));
    await tester.pumpWidget(buildSubject());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('renders NavigationRail at 880 width (just above 840 boundary)', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(880, 1024));
    await tester.pumpWidget(buildSubject());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('renders NavigationRail at 1280 width', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(buildSubject());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('currentIndex propagates to bar and rail across breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(buildSubject(currentIndex: 3));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, equals(3));

    await tester.binding.setSurfaceSize(const Size(600, 800));
    await tester.pumpWidget(buildSubject(currentIndex: 3));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, equals(3));
  });

  testWidgets('body scroll position survives resize across rail breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScrollController();
    addTearDown(controller.dispose);

    final body = ListView.builder(
      controller: controller,
      itemCount: 200,
      itemBuilder: (_, i) => SizedBox(height: 50, child: Text('item $i')),
    );

    await tester.binding.setSurfaceSize(const Size(600, 800));
    await tester.pumpWidget(buildSubject(body: body));

    controller.jumpTo(1234.0);
    await tester.pump();
    expect(controller.offset, equals(1234.0));

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(controller.offset, equals(1234.0));
  });

  group('badges', () {
    testWidgets('zero counts render no Badge widgets on the bar', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(600, 800));
      await tester.pumpWidget(buildSubject());

      expect(find.byKey(const Key('shell.bar.tasks.badge')), findsNothing);
      expect(find.byKey(const Key('shell.bar.chat.badge')), findsNothing);
      expect(find.byKey(const Key('shell.bar.budget.badge')), findsNothing);
    });

    testWidgets('non-zero counts render Badge with the numeric label on bar', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(600, 800));
      await tester.pumpWidget(
        buildSubject(tasksBadge: 3, chatBadge: 1, budgetBadge: 2),
      );

      expect(find.byKey(const Key('shell.bar.tasks.badge')), findsOneWidget);
      expect(find.byKey(const Key('shell.bar.chat.badge')), findsOneWidget);
      expect(find.byKey(const Key('shell.bar.budget.badge')), findsOneWidget);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('counts ≥ 100 clamp to "99+"', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(600, 800));
      await tester.pumpWidget(buildSubject(chatBadge: 137));

      expect(find.text('99+'), findsOneWidget);
      expect(find.text('137'), findsNothing);
    });

    testWidgets('badges render on the rail at wide widths', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(buildSubject(tasksBadge: 5));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(const Key('shell.rail.tasks.badge')), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });
}
