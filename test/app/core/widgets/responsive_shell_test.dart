import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/responsive_shell.dart';

void main() {
  Widget buildSubject({
    int currentIndex = 0,
    ValueChanged<int>? onDestinationSelected,
    VoidCallback? onSignOut,
    Widget? body,
  }) {
    return MaterialApp(
      home: ResponsiveShell(
        currentIndex: currentIndex,
        onDestinationSelected: onDestinationSelected ?? (_) {},
        onSignOut: onSignOut ?? () {},
        body: body ?? const SizedBox.shrink(),
      ),
    );
  }

  testWidgets('renders NavigationBar below 720 width', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(600, 800));
    await tester.pumpWidget(buildSubject());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('renders NavigationRail at 800 and 1280 widths', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(800, 600));
    await tester.pumpWidget(buildSubject());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

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

  testWidgets('body scroll position survives resize across 720', (
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
}
