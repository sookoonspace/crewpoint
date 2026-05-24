import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';

/// Manual-pay fallback shown when no deep link is available for the
/// counterparty's `paymentMethod`. Lets the user copy the amount (and
/// the recipient's handle if known) before paying through their own
/// channel, then offers a "Mark paid in event budget" deep link back
/// to the event's per-event budget screen.
class SettleUpFallbackSheet {
  const SettleUpFallbackSheet._();

  /// Production show — invoked by `SettleUpController`.
  static Future<void> show(
    BuildContext context,
    DebtRow row,
    AppUser? counterparty,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    final s = context.strings.budget;
    final handle = counterparty?.paymentHandle;
    final hasHandle = handle != null && handle.isNotEmpty;
    final theme = Theme.of(context);

    return Padding(
      key: const Key('budget.settleUp.fallback.sheet'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.settleUpFallbackTitle(_recipientLabel),
            style: theme.textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _amountText,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.terracotta,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Copy amount.
          OutlinedButton.icon(
            key: const Key('budget.settleUp.fallback.copyAmount'),
            onPressed: () => Clipboard.setData(ClipboardData(text: _rawAmount)),
            icon: const Icon(AppIcons.actionCopy, color: AppColors.sage),
            label: Text(s.settleUpFallbackCopyAmount),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.charcoal,
              side: const BorderSide(color: AppColors.sage),
            ),
          ),
          if (hasHandle) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('budget.settleUp.fallback.copyHandle'),
              onPressed: () => Clipboard.setData(ClipboardData(text: handle)),
              icon: const Icon(AppIcons.actionCopy, color: AppColors.sage),
              label: Text(s.settleUpFallbackCopyHandle),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.charcoal,
                side: const BorderSide(color: AppColors.sage),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            key: const Key('budget.settleUp.fallback.markPaid'),
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/dashboard/event/${row.event.id}/budget');
            },
            child: Text(
              s.settleUpFallbackMarkPaid,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.sage,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
