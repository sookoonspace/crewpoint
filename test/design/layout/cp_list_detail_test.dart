import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';

const _ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'];

class _Items extends StatelessWidget {
  const _Items({this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CpListDetail(
        placeholder: 'Select a participant to see details',
        unsavedText: const CpUnsavedText(
          title: 'Discard changes?',
          body: 'Your edits are not saved.',
          keep: 'Keep editing',
          discard: 'Discard',
        ),
        list: ListView(
          key: const Key('test.list'),
          children: [
            for (final id in _ids)
              // Each row asks with its own context, inside the layout.
              Builder(
                builder: (row) => CpListRow(
                  key: Key('test.row.$id'),
                  title: 'Person $id',
                  selected: id == selected,
                  onTap: () =>
                      CpListDetail.select(row, () => row.go('/items/$id')),
                ),
              ),
          ],
        ),
        detail: selected == null ? null : _Detail(id: selected!),
      ),
    );
  }
}

class _Detail extends StatefulWidget {
  const _Detail({required this.id});

  final String id;

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CpUnsavedChanges(
      dirty: _note.text.isNotEmpty,
      child: Column(
        key: Key('test.detail.${widget.id}'),
        children: [
          Text('Detail ${widget.id}'),
          TextField(
            key: const Key('test.detail.note'),
            controller: _note,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/items',
      builder: (_, _) => const _Items(),
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => cpListDetailPage(
            context: context,
            pageKey: state.pageKey,
            splitKey: const ValueKey('items.split'),
            child: _Items(selected: state.pathParameters['id']),
          ),
        ),
      ],
    ),
  ],
);

void main() {
  late GoRouter router;

  Future<void> pump(WidgetTester tester, Size size, String location) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = _router(location);
    await tester.pumpWidget(
      MaterialApp.router(theme: CpTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  String location() => router.routeInformationProvider.value.uri.path;

  Tristate selectedOf(WidgetTester tester, String id) => tester
      .getSemantics(find.byKey(Key('test.row.$id')))
      .flagsCollection
      .isSelected;

  group('1280 px', () {
    const wide = Size(1280, 900);

    testWidgets('nothing chosen shows a quiet prompt beside the list', (
      tester,
    ) async {
      await pump(tester, wide, '/items');
      expect(find.byKey(const Key('test.list')), findsOneWidget);
      expect(find.text('Select a participant to see details'), findsOneWidget);
    });

    testWidgets('tapping a row opens it in the panel, keeping the list', (
      tester,
    ) async {
      await pump(tester, wide, '/items');
      await tester.tap(find.byKey(const Key('test.row.a')));
      await tester.pumpAndSettle();
      expect(location(), '/items/a');
      expect(find.byKey(const Key('test.list')), findsOneWidget);
      expect(find.text('Detail a'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('listDetail.panel')),
          matching: find.text('Detail a'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a shared link opens the list with that row chosen, and back '
        'returns to the prompt', (tester) async {
      await pump(tester, wide, '/items/b');
      expect(find.byKey(const Key('test.list')), findsOneWidget);
      expect(find.text('Detail b'), findsOneWidget);
      expect(selectedOf(tester, 'b'), Tristate.isTrue);
      expect(selectedOf(tester, 'a'), Tristate.isFalse);
      router.pop();
      await tester.pumpAndSettle();
      expect(location(), '/items');
      expect(find.text('Select a participant to see details'), findsOneWidget);
    });

    testWidgets('switching rows keeps the list where it was', (tester) async {
      await pump(tester, const Size(1280, 480), '/items/a');
      await tester.drag(
        find.byKey(const Key('test.list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final scrolled = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('test.list')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels;
      expect(scrolled, greaterThan(0));
      await tester.tap(find.byKey(const Key('test.row.k')));
      await tester.pumpAndSettle();
      expect(find.text('Detail k'), findsOneWidget);
      final after = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('test.list')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels;
      expect(after, scrolled);
    });

    testWidgets('switching rows with unsaved edits asks first', (tester) async {
      await pump(tester, wide, '/items/a');
      await tester.enterText(find.byKey(const Key('test.detail.note')), 'x');
      await tester.pump();

      await tester.tap(find.byKey(const Key('test.row.b')));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('listDetail.unsaved.keep')));
      await tester.pumpAndSettle();
      expect(location(), '/items/a');
      expect(find.text('x'), findsOneWidget);

      await tester.tap(find.byKey(const Key('test.row.b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('listDetail.unsaved.discard')));
      await tester.pumpAndSettle();
      expect(location(), '/items/b');
      expect(find.text('Detail b'), findsOneWidget);
    });

    testWidgets('without edits, switching rows does not ask', (tester) async {
      await pump(tester, wide, '/items/a');
      await tester.tap(find.byKey(const Key('test.row.b')));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(location(), '/items/b');
    });
  });

  for (final narrow in const [Size(375, 800), Size(744, 1000)]) {
    group('${narrow.width.toInt()} px', () {
      testWidgets('the list alone; a row opens as its own page, and back '
          'returns', (tester) async {
        await pump(tester, narrow, '/items');
        expect(find.text('Select a participant to see details'), findsNothing);
        await tester.tap(find.byKey(const Key('test.row.a')));
        await tester.pumpAndSettle();
        expect(location(), '/items/a');
        expect(find.text('Detail a'), findsOneWidget);
        expect(find.byKey(const Key('test.list')), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('test.list')), findsOneWidget);
      });

      testWidgets('a shared link opens the detail as a full page', (
        tester,
      ) async {
        await pump(tester, narrow, '/items/c');
        expect(find.text('Detail c'), findsOneWidget);
        expect(find.byKey(const Key('test.list')), findsNothing);
      });
    });
  }

  testWidgets('narrowing turns an open detail into a full page; widening '
      'returns to the split', (tester) async {
    await pump(tester, const Size(1280, 900), '/items/a');
    expect(find.byKey(const Key('test.list')), findsOneWidget);

    tester.view.physicalSize = const Size(375, 800);
    await tester.pumpAndSettle();
    expect(find.text('Detail a'), findsOneWidget);
    expect(find.byKey(const Key('test.list')), findsNothing);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.text('Detail a'), findsOneWidget);
    expect(find.byKey(const Key('test.list')), findsOneWidget);
  });

  testWidgets('works at 200% text in dark mode at every width', (tester) async {
    for (final size in const [
      Size(375, 800),
      Size(744, 1000),
      Size(1280, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      router = _router('/items/a');
      await tester.pumpWidget(
        MaterialApp.router(
          theme: CpTheme.light(),
          darkTheme: CpTheme.dark(),
          themeMode: ThemeMode.dark,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.reset();
  });
}
