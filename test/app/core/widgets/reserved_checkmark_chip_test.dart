/// Pins the reserved-checkmark chip contract: chip width is independent
/// of selected state (the leading ✓ lives in a Visibility-maintained
/// fixed-width slot). Fixes the 2026-06-11 iPhone 12 mini Tasks-screen
/// QA where Material's FilterChip width grew/shrunk on toggle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/reserved_checkmark_chip.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }

  testWidgets('width is identical selected vs unselected for the same label', (
    tester,
  ) async {
    await pump(
      tester,
      ReservedCheckmarkChip(label: 'Mine', selected: false, onChanged: (_) {}),
    );
    final unselectedWidth = tester
        .getSize(find.byType(ReservedCheckmarkChip))
        .width;

    await pump(
      tester,
      ReservedCheckmarkChip(label: 'Mine', selected: true, onChanged: (_) {}),
    );
    final selectedWidth = tester
        .getSize(find.byType(ReservedCheckmarkChip))
        .width;

    expect(
      (selectedWidth - unselectedWidth).abs(),
      lessThan(0.5),
      reason:
          'width parity violated: unselected=$unselectedWidth, '
          'selected=$selectedWidth. The reserved checkmark slot exists '
          'to keep widths identical across selection.',
    );
  });

  testWidgets('selected: ✓ visible; unselected: ✓ in tree but invisible '
      '(Visibility.maintainSize)', (tester) async {
    await pump(
      tester,
      ReservedCheckmarkChip(label: 'Mine', selected: true, onChanged: (_) {}),
    );
    final selectedVis = tester.widget<Visibility>(find.byType(Visibility));
    expect(selectedVis.visible, isTrue);

    await pump(
      tester,
      ReservedCheckmarkChip(label: 'Mine', selected: false, onChanged: (_) {}),
    );
    final unselectedVis = tester.widget<Visibility>(find.byType(Visibility));
    expect(unselectedVis.visible, isFalse);
    expect(
      unselectedVis.maintainSize,
      isTrue,
      reason: 'maintainSize must hold the slot width when ✓ is hidden',
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tap fires onChanged with the inverted selected value', (
    tester,
  ) async {
    bool? captured;
    await pump(
      tester,
      ReservedCheckmarkChip(
        label: 'Mine',
        selected: false,
        onChanged: (v) => captured = v,
      ),
    );
    await tester.tap(find.byType(ReservedCheckmarkChip));
    expect(captured, isTrue);

    captured = null;
    await pump(
      tester,
      ReservedCheckmarkChip(
        label: 'Mine',
        selected: true,
        onChanged: (v) => captured = v,
      ),
    );
    await tester.tap(find.byType(ReservedCheckmarkChip));
    expect(captured, isFalse);
  });

  testWidgets('long label ellipsizes under a narrow constraint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: ReservedCheckmarkChip(
                label: 'An obviously long predicate label',
                selected: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final textWidget = tester.widget<Text>(
      find.text('An obviously long predicate label'),
    );
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at MediaQuery.textScaler 1.3', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ReservedCheckmarkChip(
                label: 'Mine',
                selected: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'label uses colorScheme.onSurface in BOTH selected and unselected '
    '(2026-06-11 follow-up — earlier code used onPrimary which resolves '
    'to AppColors.charcoalDark in dark mode = dark-on-dark-tint = '
    'invisible)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: ReservedCheckmarkChip(
              label: 'Mine',
              selected: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final element = tester.element(find.text('Mine'));
      final theme = Theme.of(element);
      final textWidget = tester.widget<Text>(find.text('Mine'));
      expect(
        textWidget.style?.color,
        equals(theme.colorScheme.onSurface),
        reason:
            'selected chip text must use colorScheme.onSurface so it '
            'contrasts against the faded selectedColor tint.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: ReservedCheckmarkChip(
              label: 'Mine',
              selected: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final unselectedTextWidget = tester.widget<Text>(find.text('Mine'));
      expect(
        unselectedTextWidget.style?.color,
        equals(
          Theme.of(tester.element(find.text('Mine'))).colorScheme.onSurface,
        ),
        reason:
            'unselected chip text must also use colorScheme.onSurface '
            '(same as selected — selection signal is the background, '
            'not the text color).',
      );
    },
  );
}
