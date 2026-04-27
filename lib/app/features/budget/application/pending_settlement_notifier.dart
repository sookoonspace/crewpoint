import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';

/// State recorded between launching a payment-app deep link and the user
/// returning to confirm the transfer.
class PendingSettlement {
  const PendingSettlement({
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.launchedAt,
  });

  final String payerId;
  final String payeeId;
  final double amount;
  final DateTime launchedAt;
}

/// Tracks an in-flight settlement: launches the deep link, listens for the
/// app returning to the foreground within [confirmWindow], and surfaces the
/// confirmation request through [onConfirmRequested].
///
/// The pending state lives only in memory — if the app is killed, the
/// settlement is silently dropped (the user has no proof either way and
/// auto-recording would be unsafe).
class PendingSettlementNotifier {
  PendingSettlementNotifier({
    required IUrlLauncher launcher,
    required AppLifecycleSource lifecycleSource,
    Clock? clock,
  }) : _launcher = launcher,
       _lifecycleSource = lifecycleSource,
       _clock = clock ?? const Clock() {
    _lifecycleSub = _lifecycleSource.stream.listen(_onLifecycleChanged);
  }

  static const Duration confirmWindow = Duration(seconds: 30);

  final IUrlLauncher _launcher;
  final AppLifecycleSource _lifecycleSource;
  final Clock _clock;
  late final StreamSubscription<AppLifecycleState> _lifecycleSub;

  PendingSettlement? _pending;
  void Function(PendingSettlement)? onConfirmRequested;

  bool get hasPendingSettlement => _pending != null;

  /// Launches [uri] and records pending state. Returns whether the launch
  /// succeeded (per [IUrlLauncher.launch]).
  Future<bool> launchAndPrepare(
    Uri uri, {
    required String payerId,
    required String payeeId,
    required double amount,
  }) async {
    _pending = PendingSettlement(
      payerId: payerId,
      payeeId: payeeId,
      amount: amount,
      launchedAt: _clock.now(),
    );
    return _launcher.launch(uri);
  }

  /// Drops the pending settlement (called after a confirm dialog completes,
  /// or when the user explicitly cancels).
  void clearPending() {
    _pending = null;
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final pending = _pending;
    if (pending == null) return;
    final elapsed = _clock.now().difference(pending.launchedAt);
    if (elapsed > confirmWindow) {
      _pending = null;
      return;
    }
    onConfirmRequested?.call(pending);
  }

  Future<void> dispose() async {
    await _lifecycleSub.cancel();
  }
}
