import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';

const _childKey = Key('content_max_width.child');

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  testWidgets('clamps child to maxWidth when parent is wider', (tester) async {
    await _pumpAt(
      tester,
      const Size(1280, 800),
      const ContentMaxWidth(
        maxWidth: 720,
        child: SizedBox(key: _childKey, height: 100, width: double.infinity),
      ),
    );

    final width = tester.getSize(find.byKey(_childKey)).width;
    expect(width, lessThanOrEqualTo(720));
  });

  testWidgets('passes child through unchanged when parent is narrower', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      const Size(375, 812),
      const ContentMaxWidth(
        maxWidth: 720,
        child: SizedBox(key: _childKey, height: 100, width: double.infinity),
      ),
    );

    final width = tester.getSize(find.byKey(_childKey)).width;
    expect(width, equals(375));
  });
}
