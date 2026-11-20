import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';

/// The sheet for paying what you owe: the amount, whom to pay, and a pay
/// button for each handle the payee has. A missing handle leaves its
/// button off; "Copy payment details" is always there to settle another
/// way. Pure presentation: the parent supplies handles and callbacks.
class SettleSheet extends StatelessWidget {
  const SettleSheet({
    super.key,
    required this.settlement,
    required this.currencySymbol,
    this.fromName,
    this.toName,
    this.venmoHandle,
    this.cashappHandle,
    this.onPayVenmo,
    this.onPayCashApp,
    this.onCopyDetails,
  });

  final Settlement settlement;
  final String currencySymbol;
  final String? fromName;
  final String? toName;
  final String? venmoHandle;
  final String? cashappHandle;
  final VoidCallback? onPayVenmo;
  final VoidCallback? onPayCashApp;
  final VoidCallback? onCopyDetails;

  static Future<void> show({
    required BuildContext context,
    required Settlement settlement,
    required String currencySymbol,
    String? fromName,
    String? toName,
    String? venmoHandle,
    String? cashappHandle,
    VoidCallback? onPayVenmo,
    VoidCallback? onPayCashApp,
    VoidCallback? onCopyDetails,
  }) {
    return showCpSheet<void>(
      context: context,
      builder: (_) => SettleSheet(
        settlement: settlement,
        currencySymbol: currencySymbol,
        fromName: fromName,
        toName: toName,
        venmoHandle: venmoHandle,
        cashappHandle: cashappHandle,
        onPayVenmo: onPayVenmo,
        onPayCashApp: onPayCashApp,
        onCopyDetails: onCopyDetails,
      ),
    );
  }

  bool get _hasVenmo => venmoHandle != null && venmoHandle!.isNotEmpty;
  bool get _hasCashApp => cashappHandle != null && cashappHandle!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    return Column(
      key: const Key('budget.settle.sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        Text(
          '$currencySymbol${settlement.amount.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: cp.type.headlineMedium.copyWith(color: cp.colors.text),
        ),
        Text(
          s.sheetPays(fromName ?? s.youCapital, toName ?? s.them),
          textAlign: TextAlign.center,
          style: cp.type.bodyLarge.copyWith(color: cp.colors.textMuted),
        ),
        SizedBox(height: cp.space.xs),
        CpButton(
          key: const Key('budget.settle.venmo'),
          label: _hasVenmo ? s.payWithVenmo : s.noVenmo,
          icon: CpIcons.paymentVenmo,
          expand: true,
          onPressed: _hasVenmo ? onPayVenmo : null,
        ),
        CpButton.secondary(
          key: const Key('budget.settle.cashapp'),
          label: _hasCashApp ? s.payWithCashApp : s.noCashApp,
          icon: CpIcons.paymentCashApp,
          expand: true,
          onPressed: _hasCashApp ? onPayCashApp : null,
        ),
        CpButton.text(
          key: const Key('budget.settle.copy'),
          label: s.copyPaymentDetails,
          icon: CpIcons.actionCopy,
          expand: true,
          onPressed: onCopyDetails,
        ),
      ],
    );
  }
}
