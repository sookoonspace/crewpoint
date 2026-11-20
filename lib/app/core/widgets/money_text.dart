import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A formatted amount with width-stable digits. Falls back to "$—" when
/// [currencyCode] is empty so the UI never flashes a raw locale default
/// that differs from the user's setting.
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amount,
    required this.currencyCode,
    this.style,
  });

  final double amount;
  final String currencyCode;

  /// Defaults to the label style in the text colour.
  final TextStyle? style;

  /// [amount] as this widget shows it, for labels such as a status chip.
  static String format(double amount, String currencyCode) {
    if (currencyCode.isEmpty) return r'$—';
    return NumberFormat.simpleCurrency(name: currencyCode).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final base = style ?? cp.type.labelMedium.copyWith(color: cp.colors.text);
    return Text(
      format(amount, currencyCode),
      style: base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
