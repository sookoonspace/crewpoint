import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/features/budget/application/pending_settlement_notifier.dart';

class _FakeUrlLauncher implements IUrlLauncher {
  final List<Uri> launches = [];
  bool succeed = true;

  @override
  Future<bool> launch(Uri uri) async {
    launches.add(uri);
    return succeed;
  }
}

void main() {
  late _FakeUrlLauncher launcher;
  late FakeAppLifecycleSource lifecycle;
  late DateTime now;

  setUp(() {
    launcher = _FakeUrlLauncher();
    lifecycle = FakeAppLifecycleSource();
    now = DateTime(2026, 4, 27, 12);
  });

  PendingSettlementNotifier build() => PendingSettlementNotifier(
    launcher: launcher,
    lifecycleSource: lifecycle,
    clock: Clock(() => now),
  );

  test('launchAndPrepare records pending state and launches the uri', () async {
    final n = build();
    final ok = await n.launchAndPrepare(
      Uri.parse('venmo://x'),
      payeeId: 'payee',
      payerId: 'payer',
      amount: 25,
    );
    expect(ok, isTrue);
    expect(launcher.launches, hasLength(1));
    expect(n.hasPendingSettlement, isTrue);
  });

  test('confirmation fires on resume within the 30s window', () async {
    final n = build();
    PendingSettlement? confirmed;
    n.onConfirmRequested = (s) => confirmed = s;

    await n.launchAndPrepare(
      Uri.parse('venmo://x'),
      payeeId: 'payee',
      payerId: 'payer',
      amount: 25,
    );

    // 10s later — within the window
    now = now.add(const Duration(seconds: 10));
    lifecycle.emit(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(confirmed, isNotNull);
    expect(confirmed!.payeeId, 'payee');
    expect(confirmed!.amount, closeTo(25, 0.001));
  });

  test('no confirmation fires after the 30s window', () async {
    final n = build();
    PendingSettlement? confirmed;
    n.onConfirmRequested = (s) => confirmed = s;

    await n.launchAndPrepare(
      Uri.parse('venmo://x'),
      payeeId: 'payee',
      payerId: 'payer',
      amount: 25,
    );

    // 31s later — beyond the window
    now = now.add(const Duration(seconds: 31));
    lifecycle.emit(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(confirmed, isNull);
    expect(n.hasPendingSettlement, isFalse);
  });

  test(
    'clearPending drops the pending settlement (e.g., on confirm or skip)',
    () async {
      final n = build();
      await n.launchAndPrepare(
        Uri.parse('venmo://x'),
        payeeId: 'payee',
        payerId: 'payer',
        amount: 25,
      );
      expect(n.hasPendingSettlement, isTrue);

      n.clearPending();
      expect(n.hasPendingSettlement, isFalse);
    },
  );
}
