import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';

/// Manual-pay fallback when there is no pay link for the person's payment
/// method: copy the amount (and their handle, when known), pay another
/// way, then "Mark paid in event budget" opens that event's Budget.
class SettleUpFallbackSheet {
  const SettleUpFallbackSheet._();

  /// Production show — invoked by `SettleUpController`.
  static Future<void> show(
    BuildContext context,
    DebtRow row,
    AppUser? counterparty,
  ) {
    return showCpSheet<void>(
      context: context,
      builder: (_) => _SheetBody(row: row, counterparty: counterparty),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.row, required this.counterparty});

  final DebtRow row;
  final AppUser? counterparty;

  String get _recipientLabel =>
      counterparty?.displayName ?? counterparty?.email ?? row.counterpartyUid;

  String get _amountText =>
      NumberFormat.simpleCurrency(name: row.currency).format(row.amount);

  String get _rawAmount => row.amount.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final handle = counterparty?.paymentHandle;
    final hasHandle = handle != null && handle.isNotEmpty;

    return Column(
      key: const Key('budget.settleUp.fallback.sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: cp.space.md,
      children: [
        Text(
          s.settleUpFallbackTitle(_recipientLabel),
          style: cp.type.titleLarge.copyWith(color: cp.colors.text),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CpStatusChip(status: CpStatus.due, label: _amountText),
        ),
        SizedBox(height: cp.space.xs),
        CpButton.secondary(
          key: const Key('budget.settleUp.fallback.copyAmount'),
          label: s.settleUpFallbackCopyAmount,
          icon: CpIcons.actionCopy,
          expand: true,
          onPressed: () => Clipboard.setData(ClipboardData(text: _rawAmount)),
        ),
        if (hasHandle)
          CpButton.secondary(
            key: const Key('budget.settleUp.fallback.copyHandle'),
            label: s.settleUpFallbackCopyHandle,
            icon: CpIcons.actionCopy,
            expand: true,
            onPressed: () => Clipboard.setData(ClipboardData(text: handle)),
          ),
        CpButton.text(
          key: const Key('budget.settleUp.fallback.markPaid'),
          label: s.settleUpFallbackMarkPaid,
          expand: true,
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/dashboard/event/${row.event.id}/budget');
          },
        ),
      ],
    );
  }
}
