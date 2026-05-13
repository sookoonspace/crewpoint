import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';

void main() {
  // Lottie animations loop infinitely — `pumpAndSettle` would hang.
  // Use explicit `pump(50ms)` × 3 to let the asset's async loader resolve
  // (or fall through to `errorBuilder`).
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('renders the title via emptyState.title key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmptyStatePlaceholder(title: 'No events yet')),
      ),
    );
    await pumpFrames(tester);

    expect(find.byKey(const Key('emptyState.title')), findsOneWidget);
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('renders subtitle via emptyState.subtitle key when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStatePlaceholder(
            title: 'No events yet',
            subtitle: 'Create or join one',
          ),
        ),
      ),
    );
    await pumpFrames(tester);

    expect(find.byKey(const Key('emptyState.subtitle')), findsOneWidget);
    expect(find.text('Create or join one'), findsOneWidget);
  });

  testWidgets('renders CTA via emptyState.cta key and fires onCta on tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStatePlaceholder(
            title: 'No events yet',
            ctaLabel: 'Join with Code',
            onCta: () => taps++,
          ),
        ),
      ),
    );
    await pumpFrames(tester);

    expect(find.byKey(const Key('emptyState.cta')), findsOneWidget);
    expect(find.text('Join with Code'), findsOneWidget);

    await tester.tap(find.byKey(const Key('emptyState.cta')));
    await pumpFrames(tester);
    expect(taps, 1);
  });

  testWidgets('omits CTA button when ctaLabel or onCta is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmptyStatePlaceholder(title: 'No events yet')),
      ),
    );
    await pumpFrames(tester);

    expect(find.byKey(const Key('emptyState.cta')), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('falls back to icon when lottieAsset path does not resolve', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStatePlaceholder(
            title: 'No events yet',
            lottieAsset: 'assets/animations/does_not_exist.json',
          ),
        ),
      ),
    );
    // ≥ 3 × 50 ms pumps so the lottie loader's async error can resolve
    // into the errorBuilder. NEVER pumpAndSettle — lottie loops forever.
    await pumpFrames(tester);

    expect(find.byKey(const Key('emptyState.iconFallback')), findsOneWidget);
  });

  testWidgets('forwards ctaKey onto the OutlinedButton', (tester) async {
    var taps = 0;
    const legacyKey = Key('legacy.empty.clear');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStatePlaceholder(
            title: 'No tasks match this filter',
            ctaLabel: 'Clear filters',
            onCta: () => taps++,
            ctaKey: legacyKey,
          ),
        ),
      ),
    );
    await pumpFrames(tester);

    // The OutlinedButton itself carries the forwarded key.
    final outlinedButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(outlinedButton.key, legacyKey);

    // Tapping the legacy key triggers onCta.
    await tester.tap(find.byKey(legacyKey));
    await pumpFrames(tester);
    expect(taps, 1);
  });
}
