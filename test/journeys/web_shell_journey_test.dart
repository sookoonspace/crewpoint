import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_shell.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';

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
      theme: CpTheme.light(),
      home: CpShell(
        appName: 'CrewPoint',
        signOutLabel: 'Sign out',
        destinations: const [
          CpNavDestination(id: 'home', icon: CpIcons.navHome, label: 'Home'),
          CpNavDestination(id: 'tasks', icon: CpIcons.navTasks, label: 'Tasks'),
          CpNavDestination(id: 'chat', icon: CpIcons.navChat, label: 'Chat'),
          CpNavDestination(
            id: 'budget',
            icon: CpIcons.navBudget,
            label: 'Budget',
          ),
          CpNavDestination(
            id: 'profile',
            icon: CpIcons.navProfile,
            label: 'Profile',
          ),
        ],
        currentIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        onSignOut: () {},
        body: IndexedStack(index: _index, children: _branches),
      ),
    );
  }
}

Tristate _selected(WidgetTester tester, String key) =>
    tester.getSemantics(find.byKey(Key(key))).flagsCollection.isSelected;

void main() {
  testWidgets(
    'desktop user navigates to Budget via the sidebar and survives resize '
    'to the bar',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(const _ShellDriver());

      expect(find.byKey(const Key('shell.sidebar')), findsOneWidget);
      expect(find.text('Dashboard branch'), findsOneWidget);

      await tester.tap(find.byKey(const Key('shell.rail.budget')));
      await tester.pumpAndSettle();

      expect(find.text('Budget branch'), findsOneWidget);
      expect(_selected(tester, 'shell.rail.budget'), Tristate.isTrue);

      await tester.binding.setSurfaceSize(const Size(600, 800));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell.bar')), findsOneWidget);
      expect(find.byKey(const Key('shell.sidebar')), findsNothing);
      expect(find.text('Budget branch'), findsOneWidget);
      expect(_selected(tester, 'shell.bar.budget'), Tristate.isTrue);
    },
  );
}
