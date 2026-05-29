import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';

/// Bottom sheet for choosing how to settle an outstanding balance.
///
/// Pure presentation — the parent supplies the payee's handles + callbacks.
/// Each pay button stays disabled when the corresponding handle is missing;
/// a "Copy payment details" fallback always appears so the user can settle
/// out-of-band when the recipient hasn't configured a handle.
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
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: .min,
        spacing: AppSpacing.lg,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            '$currencySymbol${settlement.amount.toStringAsFixed(2)}',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${fromName ?? 'You'} pay ${toName ?? 'them'}',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          ElevatedButton.icon(
            key: const Key('budget.settle.venmo'),
            onPressed: _hasVenmo ? onPayVenmo : null,
            icon: const Icon(AppIcons.navBudget),
            label: Text(_hasVenmo ? 'Pay with Venmo' : 'No Venmo handle'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.sage,
              foregroundColor: AppColors.white,
            ),
          ),
          OutlinedButton.icon(
            key: const Key('budget.settle.cashapp'),
            onPressed: _hasCashApp ? onPayCashApp : null,
            icon: const Icon(AppIcons.currency),
            label: Text(
              _hasCashApp ? 'Pay with Cash App' : 'No Cash App handle',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          TextButton.icon(
            key: const Key('budget.settle.copy'),
            onPressed: onCopyDetails,
            icon: const Icon(AppIcons.actionCopy),
            label: const Text('Copy payment details'),
          ),
        ],
      ),
    );
  }
}
