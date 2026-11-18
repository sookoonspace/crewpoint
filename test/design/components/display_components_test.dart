import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';

import '_pump.dart';

void main() {
  group('CpCard', () {
    testWidgets('a tappable card is one labelled button', (tester) async {
      var taps = 0;
      await pumpCp(
        tester,
        CpCard(
          key: const Key('test.card'),
          onTap: () => taps++,
          semanticLabel: 'Open people',
          child: const Text('People'),
        ),
      );
      await tester.tap(find.byKey(const Key('test.card')));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Open people')),
        matchesSemantics(
          label: 'Open people',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('a plain card draws the surface and border tokens', (
      tester,
    ) async {
      await pumpCp(tester, const CpCard(child: Text('x')), dark: true);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(CpCard),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, CpColors.dark.surface);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, CpColors.dark.border);
    });
  });

  group('CpListRow', () {
    testWidgets('shows title and subtitle, and a chevron when tappable', (
      tester,
    ) async {
      var taps = 0;
      await pumpCp(
        tester,
        CpListRow(
          key: const Key('test.row'),
          title: 'Registration opens',
          subtitle: 'Main hall',
          onTap: () => taps++,
        ),
      );
      expect(find.text('Registration opens'), findsOneWidget);
      expect(find.text('Main hall'), findsOneWidget);
      expect(find.byIcon(CpIcons.chevronRight), findsOneWidget);
      await tester.tap(find.byKey(const Key('test.row')));
      expect(taps, 1);
    });

    testWidgets('reads as one button with both lines', (tester) async {
      await pumpCp(
        tester,
        CpListRow(
          key: const Key('test.row'),
          title: 'Asha Singh',
          subtitle: 'Singh · Adult',
          selected: true,
          onTap: () {},
        ),
      );
      final node = tester.getSemantics(find.byKey(const Key('test.row')));
      expect(node.label, contains('Asha Singh'));
      expect(node.label, contains('Singh · Adult'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
    });

    testWidgets('a plain row has no chevron', (tester) async {
      await pumpCp(tester, const CpListRow(title: 'Asha'));
      expect(find.byIcon(CpIcons.chevronRight), findsNothing);
    });

    testWidgets('a group divides its rows', (tester) async {
      await pumpCp(
        tester,
        const CpRowGroup(
          children: [
            CpListRow(title: 'a'),
            CpListRow(title: 'b'),
            CpListRow(title: 'c'),
          ],
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });

  group('CpStatusChip', () {
    for (final (status, icon, fg) in [
      (CpStatus.done, CpIcons.statusDone, CpColors.light.done),
      (CpStatus.due, CpIcons.statusDue, CpColors.light.due),
      (CpStatus.overdue, CpIcons.statusOverdue, CpColors.light.overdue),
    ]) {
      testWidgets('${status.name} shows its icon and colour together', (
        tester,
      ) async {
        await pumpCp(tester, CpStatusChip(status: status, label: 'Label'));
        final iconWidget = tester.widget<Icon>(find.byIcon(icon));
        expect(iconWidget.color, fg);
        final text = tester.widget<Text>(find.text('Label'));
        expect(text.style?.color, fg);
      });
    }

    testWidgets('reads its label once', (tester) async {
      await pumpCp(
        tester,
        const CpStatusChip(
          key: Key('test.chip'),
          status: CpStatus.overdue,
          label: 'Overdue',
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('test.chip'))),
        matchesSemantics(label: 'Overdue'),
      );
    });

    testWidgets('a tag never uses status colours', (tester) async {
      await pumpCp(
        tester,
        const Column(
          children: [
            CpTag(label: 'Published'),
            CpTag(label: 'Draft', tone: CpTagTone.quiet),
          ],
        ),
      );
      const c = CpColors.light;
      final status = {c.done, c.due, c.overdue};
      for (final label in ['Published', 'Draft']) {
        final color = tester.widget<Text>(find.text(label)).style?.color;
        expect(status.contains(color), isFalse, reason: label);
      }
    });
  });

  group('CpSectionHeader', () {
    testWidgets('is a heading with a working link', (tester) async {
      var taps = 0;
      await pumpCp(
        tester,
        CpSectionHeader(
          title: 'Up next',
          actionLabel: 'Schedule',
          onAction: () => taps++,
          actionKey: const Key('test.section.action'),
        ),
      );
      expect(
        tester.getSemantics(find.text('Up next')),
        matchesSemantics(label: 'Up next', isHeader: true),
      );
      await tester.tap(find.byKey(const Key('test.section.action')));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byKey(const Key('test.section.action'))),
        matchesSemantics(
          label: 'Schedule',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('shows a quiet count', (tester) async {
      await pumpCp(
        tester,
        const CpSectionHeader(title: '148 people', trailingText: '41 groups'),
      );
      expect(find.text('41 groups'), findsOneWidget);
    });
  });

  group('CpStatCard and CpProgressRing', () {
    testWidgets('reads label, value and caption together', (tester) async {
      await pumpCp(
        tester,
        const CpStatCard(
          key: Key('test.stat'),
          icon: CpIcons.members,
          label: 'People',
          value: '148',
          caption: '41 groups',
        ),
      );
      final label = tester.getSemantics(find.byKey(const Key('test.stat')));
      expect(label.label, allOf(contains('People'), contains('148')));
      expect(label.label, contains('41 groups'));
    });

    testWidgets('a progress stat shows a labelled ring', (tester) async {
      await pumpCp(
        tester,
        const CpStatCard(
          icon: CpIcons.tasks,
          label: 'Tasks',
          value: '18/26',
          progress: 18 / 26,
          progressLabel: '18 of 26 done',
        ),
      );
      expect(find.byType(CpProgressRing), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(CpProgressRing)).label,
        contains('18 of 26 done'),
      );
    });

    testWidgets('a ring clamps its value', (tester) async {
      await pumpCp(
        tester,
        const CpProgressRing(value: 4, semanticLabel: 'All done'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('CpStatGrid', () {
    Widget grid() => const CpStatGrid(
      children: [
        CpStatCard(icon: CpIcons.members, label: 'People', value: '148'),
        CpStatCard(icon: CpIcons.tasks, label: 'Tasks', value: '18/26'),
        CpStatCard(icon: CpIcons.budget, label: 'Budget', value: r'$4,320'),
      ],
    );

    double topOf(WidgetTester tester, String label) =>
        tester.getTopLeft(find.text(label)).dy;

    testWidgets('puts three cards in a row at normal text', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpCp(tester, grid());
      expect(topOf(tester, 'Tasks'), topOf(tester, 'People'));
      expect(topOf(tester, 'Budget'), topOf(tester, 'People'));
    });

    testWidgets('stacks the cards at 200% text', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpCp(tester, grid(), textScale: 2);
      expect(topOf(tester, 'Tasks'), greaterThan(topOf(tester, 'People')));
      expect(topOf(tester, 'Budget'), greaterThan(topOf(tester, 'Tasks')));
      expect(tester.takeException(), isNull);
    });
  });

  group('CpAvatar', () {
    test('takes the first and last initials', () {
      expect(CpAvatar.initialsOf('Neha Mehta'), 'NM');
      expect(CpAvatar.initialsOf('  priya  '), 'P');
      expect(CpAvatar.initialsOf('Asha Rani Singh'), 'AS');
      expect(CpAvatar.initialsOf(''), '');
    });

    testWidgets('reads the name, not the initials', (tester) async {
      await pumpCp(tester, const CpAvatar(key: Key('a'), name: 'Neha Mehta'));
      expect(find.text('NM'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('a'))),
        matchesSemantics(label: 'Neha Mehta', isImage: true),
      );
    });

    testWidgets('an unnamed person shows an icon and a given label', (
      tester,
    ) async {
      await pumpCp(
        tester,
        const CpAvatar(key: Key('a'), name: '', semanticLabel: 'Unnamed'),
      );
      expect(find.byIcon(CpIcons.member), findsOneWidget);
      expect(tester.getSemantics(find.byKey(const Key('a'))).label, 'Unnamed');
    });

    testWidgets('a stack shows the first few and counts the rest', (
      tester,
    ) async {
      await pumpCp(
        tester,
        const CpAvatarStack(
          key: Key('s'),
          names: ['Asha Singh', 'Ravi Patel', 'Mira Kapoor', 'Jai Lal', 'Om'],
          semanticLabel: '5 attending',
        ),
      );
      expect(find.byType(CpAvatar), findsNWidgets(4));
      expect(find.text('+1'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('s'))).label,
        '5 attending',
      );
    });
  });

  group('states', () {
    testWidgets('empty state runs its action', (tester) async {
      var taps = 0;
      await pumpCp(
        tester,
        CpEmptyState(
          icon: CpIcons.members,
          title: 'No people yet',
          message: 'Add people attending.',
          actionLabel: 'Add person',
          onAction: () => taps++,
          actionKey: const Key('test.empty.action'),
        ),
      );
      expect(find.text('No people yet'), findsOneWidget);
      await tester.tap(find.byKey(const Key('test.empty.action')));
      expect(taps, 1);
    });

    testWidgets('error state retries and announces itself', (tester) async {
      var retries = 0;
      await pumpCp(
        tester,
        CpErrorState(
          title: "Couldn't load",
          message: 'Check your connection.',
          retryLabel: 'Try again',
          onRetry: () => retries++,
          retryKey: const Key('test.error.retry'),
        ),
      );
      await tester.tap(find.byKey(const Key('test.error.retry')));
      expect(retries, 1);
      final icon = tester.widget<Icon>(find.byIcon(CpIcons.statusError));
      expect(icon.color, CpColors.light.overdue);
      expect(
        tester
            .getSemantics(find.text("Couldn't load"))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    });

    testWidgets('loading state is announced, not shown as parts', (
      tester,
    ) async {
      await pumpCp(
        tester,
        const CpLoadingState(
          key: Key('l'),
          semanticLabel: 'Loading people',
          label: 'Loading…',
        ),
      );
      final node = tester.getSemantics(find.byKey(const Key('l')));
      expect(node.label, 'Loading people');
      expect(node.flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('loading rows draw placeholder rows', (tester) async {
      await pumpCp(
        tester,
        const CpLoadingState.rows(semanticLabel: 'Loading', rows: 2),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CpTopBar', () {
    testWidgets('back and actions work and are labelled', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CpTopBar(
              title: 'People',
              leadingTooltip: 'Back',
              onLeading: () => tapped.add('back'),
              leadingKey: const Key('test.bar.back'),
              actions: [
                CpTopBarAction(
                  key: const Key('test.bar.search'),
                  icon: CpIcons.actionSearch,
                  tooltip: 'Search',
                  onPressed: () => tapped.add('search'),
                ),
                CpTopBarAction(
                  key: const Key('test.bar.add'),
                  icon: CpIcons.actionAdd,
                  tooltip: 'Add',
                  primary: true,
                  onPressed: () => tapped.add('add'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('test.bar.back')));
      await tester.tap(find.byKey(const Key('test.bar.search')));
      await tester.tap(find.byKey(const Key('test.bar.add')));
      expect(tapped, ['back', 'search', 'add']);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.bySemanticsLabel('Add'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('People')),
        matchesSemantics(label: 'People', isHeader: true),
      );
    });

    testWidgets('every action is at least a 48 px target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CpTopBar(
              actions: [
                CpTopBarAction(
                  key: const Key('test.bar.add'),
                  icon: CpIcons.actionAdd,
                  tooltip: 'Add',
                  primary: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byKey(const Key('test.bar.add')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('components lay out at 200% text without overflow', (
    tester,
  ) async {
    await pumpCp(
      tester,
      textScale: 2,
      const Column(
        children: [
          CpSectionHeader(title: 'Open tasks', trailingText: '12'),
          CpStatusChip(status: CpStatus.due, label: 'Due Fri'),
          CpListRow(title: 'Confirm catering numbers', subtitle: 'Priya'),
          CpStatCard(
            icon: CpIcons.budget,
            label: 'Budget',
            value: r'$4,320',
            caption: r'of $6,000',
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
