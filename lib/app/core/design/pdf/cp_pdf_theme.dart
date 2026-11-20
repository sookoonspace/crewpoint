import 'package:pdf/pdf.dart';

import 'package:crewpoint_app/app/core/design/tokens/palette.dart';

/// `PdfColor`s for exported reports, read from the same palette as the app
/// so PDFs match it (Spec #186 Req 13). Reports are printed on white, so
/// they use the light values.
///
/// Kept apart from the Flutter tokens so the PDF builders stay free of
/// Flutter imports and remain pure Dart.
abstract final class CpPdfTheme {
  static const PdfColor text = PdfColor.fromInt(CpPalette.lightText);
  static const PdfColor textMuted = PdfColor.fromInt(CpPalette.lightTextMuted);
  static const PdfColor accent = PdfColor.fromInt(CpPalette.lightAccent);
  static const PdfColor overdue = PdfColor.fromInt(CpPalette.lightOverdue);
  static const PdfColor surface = PdfColor.fromInt(CpPalette.lightSurface);
  static const PdfColor fill = PdfColor.fromInt(CpPalette.lightFill);
  static const PdfColor border = PdfColor.fromInt(CpPalette.lightBorder);

  // Print sizes, in points.
  static const double pageMargin = 32;
  static const double gapLg = 16;
  static const double gapMd = 12;
  static const double gapSm = 8;
  static const double gapXs = 4;

  static const double titleSize = 24;
  static const double headingSize = 14;
  static const double subheadingSize = 12;
  static const double smallSize = 10;
  static const double footerSize = 9;

  /// A receipt thumbnail, and the tiny caption on its placeholder.
  static const double thumb = 40;
  static const double thumbCaptionSize = 6;
}
