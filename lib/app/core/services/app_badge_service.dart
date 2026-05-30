import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';

/// Test seam over the OS launcher app-icon badge platform channel.
///
/// Production wires a concrete implementation backed by a package such as
/// `flutter_app_badge_control` or `flutter_app_badger`. Both have rough
/// edges as of this writing (one is pre-1.0, the other discontinued) so
/// we ship [NoOpAppBadgePlatform] as the default and leave the real
/// adapter swap for a small follow-up commit.
///
/// Tests inject a recording fake to assert the service's update + clear
/// contract without touching the platform channel.
abstract class IAppBadgePlatform {
  /// Sets the launcher app-icon badge to [count]. Implementations should
  /// noop or clear when called with non-positive values (callers are
  /// expected to route zero through [clearBadge] instead).
  Future<void> setBadgeCount(int count);

  /// Removes the badge entirely.
  Future<void> clearBadge();
}

/// Production default — does nothing. Lets every other layer ship
/// end-to-end while the package choice is deferred. Swap in a real
/// adapter by overriding `appBadgePlatformProvider` in `providers.dart`.
class NoOpAppBadgePlatform implements IAppBadgePlatform {
  const NoOpAppBadgePlatform();

  @override
  Future<void> setBadgeCount(int count) async {}

  @override
  Future<void> clearBadge() async {}
}

/// Mirrors a single unread total to the OS launcher app-icon badge.
///
///  - [update] sets or clears the badge depending on the supplied total.
///  - On `AppLifecycleState.resumed`, the current total is re-applied
///    (cheap, idempotent) — some Android OEM launchers drop the badge
///    when the icon repaints after the app comes to the foreground.
///  - All platform failures are swallowed with a log; badge mirroring is
///    cosmetic and must never crash the host.
///
/// Wire from `main.dart` via `ref.listen(unreadBadgeProvider(uid))` —
/// see Phase 3b.1 in the push-notifications plan.
class AppBadgeService {
  AppBadgeService({
    required IAppBadgePlatform platform,
    required AppLifecycleSource lifecycleSource,
  }) : _platform = platform,
       _lifecycleSource = lifecycleSource {
    _lifecycleSub = _lifecycleSource.stream.listen(_onLifecycle);
  }

  final IAppBadgePlatform _platform;
  final AppLifecycleSource _lifecycleSource;
  StreamSubscription<AppLifecycleState>? _lifecycleSub;
  int _currentTotal = 0;

  /// Latest total that [update] was called with. Re-applied on resume.
  int get currentTotal => _currentTotal;

  Future<void> update(int total) async {
    _currentTotal = total;
    try {
      if (total <= 0) {
        await _platform.clearBadge();
      } else {
        await _platform.setBadgeCount(total);
      }
    } catch (e, st) {
      log(
        'app badge platform write failed (total=$total)',
        error: e,
        stackTrace: st,
        name: 'badge',
      );
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(update(_currentTotal));
  }

  void dispose() {
    unawaited(_lifecycleSub?.cancel());
    _lifecycleSub = null;
  }
}
