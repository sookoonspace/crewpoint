import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_currency_field.dart';

/// Re-exported here for backward compatibility with existing imports in
/// `create_task_screen.dart` and `edit_task_screen.dart`. The parser logic
/// now lives in `lib/app/core/widgets/forms/app_currency_field.dart`
/// (renamed from `parseBudgetEstimate` to `parseCurrencyInput`); this
/// alias keeps existing call sites compiling unchanged.
double? parseBudgetEstimate(String raw, {required String locale}) =>
    parseCurrencyInput(raw, locale: locale);

/// `BudgetEstimateField` — task-specific currency input.
///
/// Thin wrapper around the new reusable `AppCurrencyField` (from the
/// forms kit). Pre-fills the "Budget Estimate (optional)" label so the
/// Tasks feature gets consistent copy without each caller passing it.
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
    return AppCurrencyField(
      controller: controller,
      currencyCode: currencyCode,
      labelText: 'Budget Estimate (optional)',
    );
  }
}
