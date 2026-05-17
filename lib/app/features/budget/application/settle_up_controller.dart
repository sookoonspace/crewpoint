import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/data/pay_link_builder.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

/// Callback that opens the Settle-Up fallback modal sheet. Production
/// passes `SettleUpFallbackSheet.show`; tests inject a recorder.
typedef ShowSettleUpFallback =
    Future<void> Function(
      BuildContext context,
      DebtRow row,
      AppUser? counterparty,
    );

/// Pure controller for the Settle Up flow. Decides between firing a
/// `PayLinkBuilder` deep link via the `urlLauncher` boundary and
/// surfacing the manual fallback sheet. Pure-ish: no widget I/O of its
/// own, only orchestration of the injected services + callback.
class SettleUpController {
  const SettleUpController({
    required IUserRepository userRepository,
    required IUrlLauncher urlLauncher,
    required ShowSettleUpFallback showFallback,
  }) : _userRepository = userRepository,
       _urlLauncher = urlLauncher,
       _showFallback = showFallback;

  final IUserRepository _userRepository;
  final IUrlLauncher _urlLauncher;
  final ShowSettleUpFallback _showFallback;

  Future<void> handleSettleUp(BuildContext context, DebtRow row) async {
    AppUser? counterparty;
    try {
      counterparty = await _userRepository.getUser(row.counterpartyUid);
    } catch (e, st) {
      developer.log(
        'Failed to load counterparty for settle-up',
        name: 'budget.settleUp',
        error: e,
        stackTrace: st,
        level: 900,
      );
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.strings.budget.settleUpContactLoadError),
          ),
        );
        await _showFallback(context, row, null);
      }
      return;
    }

    final uri = _buildDeepLink(row, counterparty);
    if (uri == null) {
      if (context.mounted) {
        await _showFallback(context, row, counterparty);
      }
      return;
    }

    bool launched;
    try {
      launched = await _urlLauncher.launch(uri);
    } catch (e, st) {
      developer.log(
        'Settle-up launch threw',
        name: 'budget.settleUp',
        error: e,
        stackTrace: st,
        level: 900,
      );
      launched = false;
    }
    if (!launched && context.mounted) {
      await _showFallback(context, row, counterparty);
    }
  }

  Uri? _buildDeepLink(DebtRow row, AppUser? counterparty) {
    if (counterparty == null) return null;
    final handle = counterparty.paymentHandle;
    if (handle == null || handle.isEmpty) return null;
    try {
      return switch (counterparty.paymentMethod) {
        'venmo' => PayLinkBuilder.venmo(
          handle: handle,
          amount: row.amount,
          note: '${row.event.title} settle-up',
        ),
        'cashapp' => PayLinkBuilder.cashApp(handle: handle, amount: row.amount),
        // zelle / paypal / cash / null → no V1 deep link
        _ => null,
      };
    } on ArgumentError catch (e) {
      developer.log(
        'Settle-up handle failed validation: ${e.message}',
        name: 'budget.settleUp',
        level: 900,
      );
      return null;
    }
  }
}
