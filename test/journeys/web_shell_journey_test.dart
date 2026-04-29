import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/responsive_shell.dart';

class _ShellDriver extends StatefulWidget {
  const _ShellDriver();

  @override
  State<_ShellDriver> createState() => _ShellDriverState();
}

class _ShellDriverState extends State<_ShellDriver> {
  int _index = 0;

  static const _branches = [
    Center(child: Text('Dashboard branch')),
    Center(child: Text('Tasks branch')),
    Center(child: Text('Chat branch')),
    Center(child: Text('Budget branch')),
    Center(child: Text('Profile branch')),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ResponsiveShell(
        currentIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        onSignOut: () {},
        body: IndexedStack(index: _index, children: _branches),
      ),
    );
  }
}

void main() {
  testWidgets(
    'desktop user navigates to Budget via rail and survives resize to bar',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(const _ShellDriver());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Dashboard branch'), findsOneWidget);

      await tester.tap(find.byKey(const Key('shell.rail.budget')));
      await tester.pumpAndSettle();

      expect(find.text('Budget branch'), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, equals(3));

      await tester.binding.setSurfaceSize(const Size(600, 800));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Budget branch'), findsOneWidget);

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, equals(3));
    },
  );
}
