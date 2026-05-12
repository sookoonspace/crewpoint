/// `AppCurrencyField` — locale-aware currency input.
///
/// Generalises the original `BudgetEstimateField`: parses input via
/// `NumberFormat.decimalPattern(localeTag)`, validates that the result is
/// non-negative with at most 2 decimals, and renders the currency symbol
/// for the supplied `currencyCode` via `NumberFormat.simpleCurrency`.
///
/// Reusable wherever a currency-typed input is needed (task budget,
/// expense amount, future settings). Empty input parses to `null` so
/// callers can distinguish "not set" from "explicitly zero".
///
/// Locale resolution falls back to `en_US` when no `Localizations` ancestor
/// is in scope — keeps lightweight test trees + service-layer rendering
/// from blowing up.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

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

class AppCurrencyField extends StatelessWidget {
  const AppCurrencyField({
    super.key,
    required this.controller,
    required this.currencyCode,
    this.labelText,
    this.helperText,
    this.validator,
  });

  final TextEditingController controller;
  final String currencyCode;
  final String? labelText;
  final String? helperText;

  /// Layered validator. Runs in addition to the built-in numeric
  /// validator; returning a non-null string short-circuits the field
  /// into an error state.
  final FormFieldValidator<String>? validator;

  String _resolveLocaleTag(BuildContext context) {
    // `Localizations.maybeLocaleOf` returns null when there's no
    // Localizations ancestor; in that case fall back to en_US so tests
    // and service-layer renders still work.
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.toLanguageTag() ?? 'en_US';
  }

  String _symbol() =>
      NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;

  @override
  Widget build(BuildContext context) {
    final localeTag = _resolveLocaleTag(context);
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        prefixText: '${_symbol()} ',
        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        border: const OutlineInputBorder(borderRadius: AppRadius.borderLg),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      validator: (value) {
        try {
          parseCurrencyInput(value ?? '', locale: localeTag);
        } on FormatException {
          return 'Must be a non-negative number with up to 2 decimals';
        }
        return validator?.call(value);
      },
    );
  }
}
