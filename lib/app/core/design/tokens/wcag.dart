import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.1 contrast-ratio helpers.
///
/// All math is pure (no Flutter UI deps beyond `Color`) so this file is
/// safe to import from tests, services, or PDF code.
///
/// References:
///   - https://www.w3.org/TR/WCAG21/#contrast-minimum
///   - https://www.w3.org/TR/WCAG21/#dfn-relative-luminance

/// Minimum WCAG AA contrast for normal-size body text on a background.
const double kWcagAaBodyText = 4.5;

/// Minimum WCAG AA contrast for large text (≥18 pt regular OR ≥14 pt
/// bold) and for non-text UI components like icon buttons + form
/// outlines.
const double kWcagAaLargeText = 3.0;

/// Returns the WCAG 2.1 contrast ratio between two opaque colors.
///
/// Range: 1.0 (identical) to 21.0 (black on white). The function is
/// symmetric — `contrastRatio(a, b) == contrastRatio(b, a)`.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Relative luminance per WCAG 2.1 §1.4.3 (non-linear sRGB → linear
/// → weighted sum). Alpha is ignored — pass already-flattened colors.
double _relativeLuminance(Color color) {
  final r = _channel(color.r);
  final g = _channel(color.g);
  final b = _channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _channel(double v) {
  // `Color.r/g/b` already returns the 0..1 sRGB value; no /255 needed.
  return v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4) as double;
}
