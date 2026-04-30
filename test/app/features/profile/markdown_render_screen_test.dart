import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/profile/presentation/markdown_render_screen.dart';

void main() {
  testWidgets('renders the H1 from the bundled asset and surfaces frontmatter '
      'stamps above the body', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarkdownRenderScreen(
          title: 'Privacy',
          assetPath: 'assets/legal/privacy-policy.md',
          hostedUrl: 'https://example.com/privacy',
        ),
      ),
    );
    // Drain the FutureBuilder microtask + a frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Markdown body renders (proves the asset loaded + parser
    // stripped the frontmatter; the H1 is the first body line).
    expect(find.text('CrewPoint Privacy Policy'), findsOneWidget);

    // Frontmatter stamps render above the body via stable Keys.
    expect(
      find.byKey(const Key('legal.stamp.effective'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('legal.stamp.lastUpdated'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('asset-load failure renders the fallback "View online" button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarkdownRenderScreen(
          title: 'Missing',
          assetPath: 'assets/legal/does-not-exist.md',
          hostedUrl: 'https://example.com/missing',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('legal.fallback.viewOnline')), findsOneWidget);
    expect(find.text('https://example.com/missing'), findsOneWidget);
  });
}
