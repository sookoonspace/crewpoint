import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/form_card_shell.dart';

const _shellKey = Key('form.card.shell');
const _childKey = Key('form_card_shell.child');

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: FormCardShell(child: SizedBox(key: _childKey, height: 200)),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'wraps child in a Card at viewports above the compact breakpoint',
    (tester) async {
      await _pumpAt(tester, const Size(1280, 800));

      expect(find.byKey(_shellKey), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(_childKey), findsOneWidget);
    },
  );

  testWidgets('passes child through without a Card at compact viewports', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(375, 812));

    expect(find.byKey(_shellKey), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byKey(_childKey), findsOneWidget);
  });
}
