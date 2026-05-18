import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography using Poppins for headings and Inter for body text.
abstract final class AppTypography {
  /// Tabular-figures style for numbers that line up vertically (balance
  /// tile, stat triplet, money text). Width-stable digits so a "$15" → "$150"
  /// transition doesn't shift adjacent layout. Inter ships proportional
  /// figures by default; the OpenType `tnum` feature swaps in monospaced
  /// digits without changing letterform.
  static TextStyle numberDisplay({Color? color}) => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextTheme textTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? const Color(0xFF2D3436)
        : const Color(0xFFF8F9FA);

    return TextTheme(
      displayLarge: GoogleFonts.poppins(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      // Body text: 1.4 line-height + 0.15 letter-spacing tunes Inter
      // for comfortable reading at the small sizes Material defaults
      // to. Display + headline sizes left untouched so visual rhythm
      // doesn't shift.
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
        letterSpacing: 0.15,
      ),
      // Body default raised 14→16 to clear the "any age" readability floor.
      // Existing screens that need the smaller variant should use bodySmall (12)
      // explicitly; bodyLarge stays at 16 (matches bodyMedium now — same size,
      // bodyMedium remains the Material 3 default for `Text` without style).
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
        letterSpacing: 0.15,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
        letterSpacing: 0.15,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }
}
