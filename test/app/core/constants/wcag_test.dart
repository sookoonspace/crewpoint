import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/wcag.dart';

void main() {
  test('black on white returns the maximum WCAG contrast ratio of 21.0', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21.0, 0.01),
    );
  });

  test('matched colors return 1.0 (no contrast)', () {
    expect(
      contrastRatio(const Color(0xFF6B9080), const Color(0xFF6B9080)),
      closeTo(1.0, 0.001),
    );
  });

  test(
    '#767676 on white sits right at the WCAG AA body-text threshold (~4.54)',
    () {
      // The W3C uses #767676 as the canonical "barely passes 4.5" example.
      final ratio = contrastRatio(
        const Color(0xFF767676),
        const Color(0xFFFFFFFF),
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(ratio, lessThan(5.0));
    },
  );

  test('contrastRatio is symmetric: ratio(a, b) == ratio(b, a)', () {
    const fg = Color(0xFF2D3436);
    const bg = Color(0xFFEADDCE);
    expect(contrastRatio(fg, bg), closeTo(contrastRatio(bg, fg), 0.000001));
  });
}
