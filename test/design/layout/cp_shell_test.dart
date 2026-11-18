import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/layout/cp_shell.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';

void main() {
  Future<List<int>> pumpShell(
    WidgetTester tester,
    Size size, {
    int tasks = 0,
    ThemeMode mode = ThemeMode.light,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chosen = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: CpTheme.light(),
        darkTheme: CpTheme.dark(),
        themeMode: mode,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: CpShell(
            appName: 'CrewPoint',
            signOutLabel: 'Sign out',
            destinations: [
              const CpNavDestination(
                id: 'home',
                icon: CpIcons.navHome,
                label: 'Home',
              ),
              CpNavDestination(
                id: 'tasks',
                icon: CpIcons.navTasks,
                label: 'Tasks',
                badge: tasks,
              ),
              const CpNavDestination(
                id: 'profile',
                icon: CpIcons.navProfile,
                label: 'Profile',
              ),
            ],
            currentIndex: 0,
            onDestinationSelected: chosen.add,
            onSignOut: () => chosen.add(-1),
            body: const ColoredBox(
              key: Key('test.body'),
              color: Colors.transparent,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    return chosen;
  }

  testWidgets('375 px: one column with the bottom bar', (tester) async {
    final chosen = await pumpShell(tester, const Size(375, 800));
    expect(find.byKey(const Key('shell.bar')), findsOneWidget);
    expect(find.byKey(const Key('shell.sidebar')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('test.body'))).width, 375);
    await tester.tap(find.byKey(const Key('shell.bar.tasks')));
    expect(chosen, [1]);
  });

  testWidgets('744 px: the bar, with the column capped and centred', (
    tester,
  ) async {
    await pumpShell(tester, const Size(744, 900));
    expect(find.byKey(const Key('shell.bar')), findsOneWidget);
    final column = tester.getRect(find.byKey(const Key('test.body')));
    expect(column.width, lessThan(744));
    expect(column.width, greaterThanOrEqualTo(600));
    expect(column.left, closeTo(744 - column.right, 1));
  });

  testWidgets('1280 px: a sidebar instead of the bar, full width body', (
    tester,
  ) async {
    final chosen = await pumpShell(tester, const Size(1280, 800));
    expect(find.byKey(const Key('shell.sidebar')), findsOneWidget);
    expect(find.byKey(const Key('shell.bar')), findsNothing);
    expect(find.text('CrewPoint'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shell.rail.profile')));
    await tester.tap(find.byKey(const Key('shell.rail.signOut')));
    expect(chosen, [2, -1]);
  });

  testWidgets('the body keeps its place across the breakpoint', (tester) async {
    await pumpShell(tester, const Size(1280, 800));
    final before = tester.element(find.byKey(const Key('test.body')));
    tester.view.physicalSize = const Size(375, 800);
    await tester.pump();
    expect(tester.element(find.byKey(const Key('test.body'))), same(before));
  });

  testWidgets('badges show counts, 99+ past a hundred, and read with the '
      'label', (tester) async {
    await pumpShell(tester, const Size(375, 800), tasks: 150);
    expect(find.byKey(const Key('shell.bar.tasks.badge')), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    expect(find.bySemanticsLabel('Tasks, 99+'), findsOneWidget);
    await pumpShell(tester, const Size(375, 800));
    expect(find.byKey(const Key('shell.bar.tasks.badge')), findsNothing);
    await pumpShell(tester, const Size(1280, 800), tasks: 3);
    expect(find.byKey(const Key('shell.rail.tasks.badge')), findsOneWidget);
  });

  for (final size in const [Size(375, 800), Size(1280, 800)]) {
    testWidgets('${size.width.toInt()} px: 48 px targets at 200% text, dark', (
      tester,
    ) async {
      await pumpShell(tester, size, mode: ThemeMode.dark, textScale: 2);
      expect(tester.takeException(), isNull);
      final prefix = size.width < 840 ? 'shell.bar' : 'shell.rail';
      for (final id in ['home', 'tasks', 'profile']) {
        expect(
          tester.getSize(find.byKey(Key('$prefix.$id'))).height,
          greaterThanOrEqualTo(48),
        );
      }
    });
  }
}
