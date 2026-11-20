import 'package:intl/intl.dart';

/// Parse a locale-tagged currency-like string into a non-negative
/// `double` with at most 2 decimals.
///
/// Returns `null` for empty/whitespace input (callers persist as
/// "no value"). Throws [FormatException] for malformed, negative, or
/// over-precise values; UI validators map this to an error string.
double? parseCurrencyInput(String raw, {required String locale}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final format = NumberFormat.decimalPattern(locale);
  final parsed = format.tryParse(trimmed);
  if (parsed == null) throw const FormatException('not a number');
  if (parsed < 0) throw const FormatException('negative');

  final asDouble = parsed.toDouble();
  if (((asDouble * 100).round() - asDouble * 100).abs() > 1e-9) {
    throw const FormatException('more than 2 decimals');
  }
  return asDouble;
}
