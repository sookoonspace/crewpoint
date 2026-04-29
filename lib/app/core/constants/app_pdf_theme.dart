import 'package:pdf/pdf.dart';

/// `PdfColor` mirrors of [AppColors] for branded PDF reports.
///
/// Kept separate from `AppColors` (which is a Flutter `Color` palette)
/// so the PDF builders stay free of Flutter imports and remain pure
/// Dart, testable without a binding.
abstract final class AppPdfTheme {
  static const PdfColor charcoal = PdfColor.fromInt(0xFF2D3436);
  static const PdfColor charcoalLight = PdfColor.fromInt(0xFF636E72);

  static const PdfColor sage = PdfColor.fromInt(0xFF6B9080);
  static const PdfColor sageLight = PdfColor.fromInt(0xFFA4C3B2);

  static const PdfColor terracotta = PdfColor.fromInt(0xFFCC704B);
  static const PdfColor terracottaLight = PdfColor.fromInt(0xFFE0956F);

  static const PdfColor cream = PdfColor.fromInt(0xFFEADDCE);
  static const PdfColor white = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor offWhite = PdfColor.fromInt(0xFFF8F9FA);
  static const PdfColor lightGrey = PdfColor.fromInt(0xFFDFE6E9);
  static const PdfColor slate = PdfColor.fromInt(0xFFB2BEC3);
}
