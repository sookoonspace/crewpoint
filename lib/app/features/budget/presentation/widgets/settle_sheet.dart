import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';

/// Bottom sheet for recording a settlement payment.
class SettleSheet extends StatefulWidget {
  const SettleSheet({
    super.key,
    required this.settlement,
    this.fromName,
    this.toName,
    this.paymentMethod,
    this.paymentHandle,
    this.onRecordPayment,
  });

  final Settlement settlement;
  final String? fromName;
  final String? toName;
  final String? paymentMethod;
  final String? paymentHandle;
  final VoidCallback? onRecordPayment;

  static Future<void> show({
    required BuildContext context,
    required Settlement settlement,
    String? fromName,
    String? toName,
    String? paymentMethod,
    String? paymentHandle,
    VoidCallback? onRecordPayment,
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
        fromName: fromName,
        toName: toName,
        paymentMethod: paymentMethod,
        paymentHandle: paymentHandle,
        onRecordPayment: onRecordPayment,
      ),
    );
  }

  @override
  State<SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<SettleSheet> {
  bool _showSuccess = false;

  void _recordPayment() {
    widget.onRecordPayment?.call();
    setState(() => _showSuccess = true);
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return Padding(
        padding: EdgeInsets.only(
          top: AppSpacing.xxl,
          bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: .min,
          spacing: AppSpacing.lg,
          children: [
            Lottie.asset(
              'assets/animations/success.json',
              width: 80,
              height: 80,
              errorBuilder: (_, _, _) => const Icon(
                Icons.check_circle,
                size: 64,
                color: AppColors.sage,
              ),
            ),
            Text(
              'Payment recorded!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.sage,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final hasPaymentMethod =
        widget.paymentMethod != null && widget.paymentMethod!.isNotEmpty;

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
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Amount
          Text(
            '\$${widget.settlement.amount.toStringAsFixed(2)}',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),

          // Transfer description
          Text(
            '${widget.fromName ?? 'Someone'} pays ${widget.toName ?? 'someone'}',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.darkGrey),
          ),

          // Payment method info
          if (hasPaymentMethod)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  const Icon(Icons.payment, color: AppColors.sage),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          _formatMethod(widget.paymentMethod!),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        if (widget.paymentHandle != null)
                          Text(
                            widget.paymentHandle!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.darkGrey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'No payment method set \u2014 ask them directly',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mediumGrey,
                fontStyle: FontStyle.italic,
              ),
            ),

          const SizedBox(height: AppSpacing.sm),

          PrimaryButton(label: 'Record Payment', onPressed: _recordPayment),
        ],
      ),
    );
  }

  String _formatMethod(String method) => switch (method) {
    'venmo' => 'Venmo',
    'zelle' => 'Zelle',
    'cashapp' => 'Cash App',
    'paypal' => 'PayPal',
    'cash' => 'Cash',
    _ => method,
  };
}
