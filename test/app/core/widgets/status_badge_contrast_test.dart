import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/widgets/status_badge.dart';

/// Computes the WCAG 2.1 relative luminance of an opaque sRGB colour.
/// Channels are gamma-decoded then linearly weighted per the spec.
double _luminance(Color c) {
  double channel(double v) {
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio between two opaque colours.
double _contrast(Color fg, Color bg) {
  final l1 = _luminance(fg);
  final l2 = _luminance(bg);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Cream-surface contrast spot-check for status semantic foregrounds.
///
/// All four status foregrounds must achieve at least the AA-Large
/// threshold (3.0:1) against the cream surface so the badge text + icon
/// reads even at a glance. The "doing" amber-brown is the riskiest tone —
/// the spec calls it out explicitly (req #1, screen-design-refresh-spec).
///
/// If any of these starts failing, the corresponding token in
/// `app_colors.dart` regressed; either bump its darkness or restore the
/// previous value.
void main() {
  group('Status foreground tokens clear AA-Large on cream', () {
    test('todo foreground exceeds 3.0:1', () {
      final ratio = _contrast(AppColors.statusTodoFg, AppColors.cream);
      expect(
        ratio,
        greaterThan(3.0),
        reason: 'measured ${ratio.toStringAsFixed(2)}',
      );
    });

    test('doing foreground exceeds 3.0:1', () {
      final ratio = _contrast(AppColors.statusDoingFg, AppColors.cream);
      expect(
        ratio,
        greaterThan(3.0),
        reason: 'measured ${ratio.toStringAsFixed(2)}',
      );
    });

    test('done foreground exceeds 3.0:1', () {
      final ratio = _contrast(AppColors.statusDoneFg, AppColors.cream);
      expect(
        ratio,
        greaterThan(3.0),
        reason: 'measured ${ratio.toStringAsFixed(2)}',
      );
    });

    test('urgent foreground exceeds 3.0:1', () {
      final ratio = _contrast(AppColors.statusUrgentFg, AppColors.cream);
      expect(
        ratio,
        greaterThan(3.0),
        reason: 'measured ${ratio.toStringAsFixed(2)}',
      );
    });
  });

  testWidgets('every StatusBadge variant renders on a cream surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.cream,
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge.todo(label: 'To do'),
                StatusBadge.doing(label: 'Doing'),
                StatusBadge.done(label: 'Done'),
                StatusBadge.urgent(label: 'Urgent'),
                StatusBadge.info(label: 'Info'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // All five badges materialised.
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('Doing'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Info'), findsOneWidget);
  });
}
