import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';

const _bodyKey = Key('dashboard.body.clamped');

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: DashboardScreen())),
  );
  await tester.pump();
}

void main() {
  testWidgets('clamps body to <= 720 px on a desktop viewport', (tester) async {
    await _pumpAt(tester, const Size(1280, 800));

    final width = tester.getSize(find.byKey(_bodyKey)).width;
    expect(width, lessThanOrEqualTo(720));
  });

  testWidgets('body fills the viewport on a phone-width viewport', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(375, 812));

    final width = tester.getSize(find.byKey(_bodyKey)).width;
    expect(width, greaterThan(300));
    expect(width, lessThanOrEqualTo(375));
  });
}
