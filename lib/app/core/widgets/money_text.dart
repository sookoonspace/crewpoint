import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';

/// Direction of a monetary value — drives the semantic color.
enum MoneySign { owedToYou, youOwe, neutral }

/// Formatted currency amount with semantic coloring and width-stable digits.
/// Falls back to "$—" when [currencyCode] is empty so the UI never flashes
/// a raw locale default that differs from the user's setting.
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amount,
    required this.currencyCode,
    this.sign = MoneySign.neutral,
    this.style,
  });

  final double amount;
  final String currencyCode;
  final MoneySign sign;
  final TextStyle? style;

  Color _signColor(BuildContext context) => switch (sign) {
    MoneySign.owedToYou => AppColors.moneyOwedToYouFg,
    MoneySign.youOwe => AppColors.moneyYouOweFg,
    MoneySign.neutral => Theme.of(context).colorScheme.onSurface,
  };

  String _format() {
    if (currencyCode.isEmpty) return r'$—';
    return NumberFormat.simpleCurrency(name: currencyCode).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.labelMedium;
    return Text(
      _format(),
      style: base?.copyWith(
        color: _signColor(context),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
