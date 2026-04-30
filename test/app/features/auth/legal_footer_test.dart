import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/legal_footer.dart';

class _FakeLauncher {
  Uri? lastUri;
  LaunchMode? lastMode;
  bool returnValue = true;

  Future<bool> launch(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    lastUri = uri;
    lastMode = mode;
    return returnValue;
  }
}

void main() {
  testWidgets('renders both link selectors and tappable copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LegalFooter())),
    );
    await tester.pump();

    expect(find.byKey(LegalFooter.termsKey), findsOneWidget);
    expect(find.byKey(LegalFooter.privacyKey), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets(
    'tapping Privacy invokes the launcher with the per-flavor /privacy URL',
    (tester) async {
      final fake = _FakeLauncher();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LegalFooter(urlLauncher: fake.launch)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(LegalFooter.privacyKey));
      await tester.pump();

      // Default flavor (test env has FLAVOR unset) resolves to dev.
      expect(fake.lastUri.toString(), endsWith('/privacy'));
      expect(fake.lastUri!.host, contains('crewpoint'));
    },
  );

  testWidgets(
    'tapping Terms invokes the launcher with the per-flavor /terms URL',
    (tester) async {
      final fake = _FakeLauncher();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LegalFooter(urlLauncher: fake.launch)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(LegalFooter.termsKey));
      await tester.pump();

      expect(fake.lastUri.toString(), endsWith('/terms'));
    },
  );
}
