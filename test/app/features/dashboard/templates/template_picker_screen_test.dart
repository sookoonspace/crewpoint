import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_template.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/template_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../harness/system_templates.dart';

/// Req 63: the first step of creation lists the six templates, with
/// loading and error states, at 375 px and 200% text.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Future<List<EventTemplateInfo>> Function() load, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(375, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [templateCatalogueProvider.overrideWith((ref) => load())],
        child: const MaterialApp(home: TemplatePickerScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists the six templates, Party and Blank as quick', (
    tester,
  ) async {
    await pump(tester, () async => systemTemplatesFromFiles());
    for (final id in [
      'blank',
      'party',
      'wedding',
      'cricket_tournament',
      'golf_outing',
      'convention',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(Key('events.create.template.$id')),
        200,
      );
    }
    expect(find.text('Just a title and a date'), findsNWidgets(2));
  });

  testWidgets('fits at 200% text', (tester) async {
    await pump(tester, () async => systemTemplatesFromFiles(), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure explains and retries', (tester) async {
    var calls = 0;
    await pump(tester, () async {
      calls++;
      if (calls == 1) throw StateError('broken');
      return systemTemplatesFromFiles();
    });
    expect(
      find.byKey(const Key('events.create.templates.error')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('events.create.templates.retry')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('events.create.templates')), findsOneWidget);
  });
}
