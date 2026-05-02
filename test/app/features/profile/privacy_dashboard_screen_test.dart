import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/profile/presentation/privacy_dashboard_screen.dart';

void main() {
  testWidgets(
    'shows the LEGAL DOCUMENTS section with privacy + terms rows tappable',
    (tester) async {
      // Tall surface so the lazy ListView builds the LEGAL DOCUMENTS
      // section without needing a programmatic scroll.
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: PrivacyDashboardScreen()),
      );
      await tester.pump();

      // Section label present (may be offstage in the ListView).
      expect(find.text('LEGAL DOCUMENTS', skipOffstage: false), findsOneWidget);

      // Both rows present and tappable via stable selectors.
      final privacyTile = find.byKey(
        const Key('privacyDashboard.legal.privacy'),
        skipOffstage: false,
      );
      final termsTile = find.byKey(
        const Key('privacyDashboard.legal.terms'),
        skipOffstage: false,
      );
      expect(privacyTile, findsOneWidget);
      expect(termsTile, findsOneWidget);
    },
  );

  testWidgets('clamps body to <= 720 px on a desktop viewport', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PrivacyDashboardScreen()));
    await tester.pump();

    final width = tester
        .getSize(find.byKey(const Key('privacyDashboard.body.clamped')))
        .width;
    expect(width, lessThanOrEqualTo(720));
  });
}
