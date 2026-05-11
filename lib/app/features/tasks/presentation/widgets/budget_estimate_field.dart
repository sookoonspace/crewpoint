import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Locale-aware parser for the task budget estimate.
///
/// Returns `null` for empty/whitespace input (persists as "no estimate").
/// Throws [FormatException] for negative, non-numeric, or > 2-decimal input.
///
/// Locale is provided as a `BCP-47` tag (e.g. `en_US`, `de_DE`) so the
/// decimal separator matches what `NumberFormat.simpleCurrency` renders.
double? parseBudgetEstimate(String raw, {required String locale}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final format = NumberFormat.decimalPattern(locale);
  final value = format.tryParse(trimmed);
  if (value == null) throw const FormatException('not a number');
  if (value < 0) throw const FormatException('negative');

  final asDouble = value.toDouble();
  // Round-trip check: > 2 decimals → reject.
  if (((asDouble * 100).round() - asDouble * 100).abs() > 1e-9) {
    throw const FormatException('more than 2 decimals');
  }
  return asDouble;
}

/// Form field for the task budget estimate. Prefixes the event currency
/// symbol and validates via [parseBudgetEstimate].
class BudgetEstimateField extends StatelessWidget {
  const BudgetEstimateField({
    super.key,
    required this.controller,
    required this.currencyCode,
  });

  final TextEditingController controller;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final symbol = NumberFormat.simpleCurrency(
      name: currencyCode,
    ).currencySymbol;

    return TextFormField(
      key: const Key('tasks.create.budget'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Budget Estimate (optional)',
        prefixText: '$symbol ',
        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        border: const OutlineInputBorder(borderRadius: AppRadius.borderLg),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      validator: (value) {
        try {
          parseBudgetEstimate(value ?? '', locale: localeTag);
          return null;
        } on FormatException {
          return 'Estimate must be a non-negative number with up to 2 decimals';
        }
      },
    );
  }
}
