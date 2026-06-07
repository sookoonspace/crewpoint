import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Computes the WCAG 2.1 relative luminance of an sRGB color.
///
/// See https://www.w3.org/TR/WCAG21/#dfn-relative-luminance.
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Returns the WCAG 2.1 contrast ratio between two colors. Always >= 1.0.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Asserts that the foreground / background pair meets WCAG AA. Default
/// 4.5 is the AA threshold for body text; pass `minimum: 3.0` for large
/// text or auxiliary UI.
void expectAaContrast(
  Color fg,
  Color bg, {
  double minimum = 4.5,
  String? reason,
}) {
  final ratio = contrastRatio(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason:
        reason ??
        'fg=${_hex(fg)} on bg=${_hex(bg)} contrast '
            '${ratio.toStringAsFixed(2)}:1 < required $minimum:1',
  );
}

String _hex(Color c) {
  String h(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}
