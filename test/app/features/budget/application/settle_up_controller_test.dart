import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/application/settle_up_controller.dart';
import 'package:crewpoint_app/app/features/budget/data/pay_link_builder.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

class _RecordingLauncher implements IUrlLauncher {
  final List<Uri> launched = [];
  bool returnValue = true;
  Object? throwOnLaunch;

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    if (throwOnLaunch != null) throw throwOnLaunch!;
    return returnValue;
  }
}

class _FakeUserRepo implements IUserRepository {
  final Map<String, AppUser> users = {};
  Object? throwOnGet;

  @override
  Future<AppUser?> getUser(String uid) async {
    if (throwOnGet != null) throw throwOnGet!;
    return users[uid];
  }

  @override
  Future<void> saveProfile({
    required String uid,
    required String displayName,
    String? photoUrl,
    String? paymentMethod,
    String? paymentHandle,
    String? venmoHandle,
    String? cashappHandle,
  }) async => throw UnimplementedError();

  @override
  Future<void> createUserIfNotExists({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    List<String> providerIds = const [],
  }) async => throw UnimplementedError();

  @override
  Future<void> addFcmToken({required String uid, required String token}) =>
      throw UnimplementedError();

  @override
  Future<void> removeFcmToken({required String uid, required String token}) =>
      throw UnimplementedError();
}

/// Recording fallback-sheet stub. Tests inspect `calls` to verify that
/// the controller routed to the fallback path.
class _FallbackRecorder {
  final List<({DebtRow row, AppUser? counterparty})> calls = [];

  Future<void> show(
    BuildContext context,
    DebtRow row,
    AppUser? counterparty,
  ) async {
    calls.add((row: row, counterparty: counterparty));
  }
}

const _event = EventModel(
  id: 'evt-1',
  title: 'Tahoe Trip',
  creatorId: 'me',
  memberIds: ['me', 'alex'],
  currency: 'USD',
);

const _debt = DebtRow(
  counterpartyUid: 'alex',
  event: _event,
  amount: 45,
  currency: 'USD',
);

SettleUpController _build({
  required IUserRepository userRepo,
  required IUrlLauncher launcher,
  required _FallbackRecorder fallback,
}) {
  return SettleUpController(
    userRepository: userRepo,
    urlLauncher: launcher,
    showFallback: fallback.show,
  );
}

void main() {
  testWidgets(
    'venmo path — launches Venmo deep link with handle + amount + note',
    (tester) async {
      final repo = _FakeUserRepo();
      repo.users['alex'] = const AppUser(
        uid: 'alex',
        email: 'alex@example.com',
        paymentMethod: 'venmo',
        paymentHandle: 'alex_v',
      );
      final launcher = _RecordingLauncher();
      final fallback = _FallbackRecorder();
      final controller = _build(
        userRepo: repo,
        launcher: launcher,
        fallback: fallback,
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      final ctx = tester.element(find.byType(Scaffold));
      await controller.handleSettleUp(ctx, _debt);

      expect(launcher.launched, hasLength(1));
      expect(
        launcher.launched.single,
        PayLinkBuilder.venmo(
          handle: 'alex_v',
          amount: 45,
          note: 'Tahoe Trip settle-up',
        ),
      );
      expect(fallback.calls, isEmpty);
    },
  );

  testWidgets('cashapp path — launches Cash App URL with handle + amount', (
    tester,
  ) async {
    final repo = _FakeUserRepo();
    repo.users['alex'] = const AppUser(
      uid: 'alex',
      email: 'alex@example.com',
      paymentMethod: 'cashapp',
      paymentHandle: 'alexcash',
    );
    final launcher = _RecordingLauncher();
    final fallback = _FallbackRecorder();
    final controller = _build(
      userRepo: repo,
      launcher: launcher,
      fallback: fallback,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final ctx = tester.element(find.byType(Scaffold));
    await controller.handleSettleUp(ctx, _debt);

    expect(launcher.launched, hasLength(1));
    expect(
      launcher.launched.single,
      PayLinkBuilder.cashApp(handle: 'alexcash', amount: 45),
    );
    expect(fallback.calls, isEmpty);
  });

  testWidgets(
    'unsupported platforms — zelle / paypal / cash → no launch; fallback opens with counterparty',
    (tester) async {
      for (final method in const ['zelle', 'paypal', 'cash']) {
        final repo = _FakeUserRepo();
        repo.users['alex'] = AppUser(
          uid: 'alex',
          email: 'alex@example.com',
          paymentMethod: method,
          paymentHandle: 'whatever',
        );
        final launcher = _RecordingLauncher();
        final fallback = _FallbackRecorder();
        final controller = _build(
          userRepo: repo,
          launcher: launcher,
          fallback: fallback,
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );
        final ctx = tester.element(find.byType(Scaffold));
        await controller.handleSettleUp(ctx, _debt);

        expect(launcher.launched, isEmpty, reason: 'no launch for $method');
        expect(fallback.calls, hasLength(1));
        expect(fallback.calls.single.counterparty?.paymentMethod, method);
      }
    },
  );

  testWidgets('missing paymentHandle → fallback opens; no launch', (
    tester,
  ) async {
    final repo = _FakeUserRepo();
    repo.users['alex'] = const AppUser(
      uid: 'alex',
      email: 'alex@example.com',
      paymentMethod: 'venmo',
    );
    final launcher = _RecordingLauncher();
    final fallback = _FallbackRecorder();
    final controller = _build(
      userRepo: repo,
      launcher: launcher,
      fallback: fallback,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final ctx = tester.element(find.byType(Scaffold));
    await controller.handleSettleUp(ctx, _debt);

    expect(launcher.launched, isEmpty);
    expect(fallback.calls, hasLength(1));
  });

  testWidgets('malformed handle (regex fails) → fallback opens; no launch', (
    tester,
  ) async {
    final repo = _FakeUserRepo();
    repo.users['alex'] = const AppUser(
      uid: 'alex',
      email: 'alex@example.com',
      paymentMethod: 'venmo',
      paymentHandle: 'has spaces and bad chars!',
    );
    final launcher = _RecordingLauncher();
    final fallback = _FallbackRecorder();
    final controller = _build(
      userRepo: repo,
      launcher: launcher,
      fallback: fallback,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final ctx = tester.element(find.byType(Scaffold));
    await controller.handleSettleUp(ctx, _debt);

    expect(launcher.launched, isEmpty);
    expect(fallback.calls, hasLength(1));
  });

  testWidgets('launcher returns false → fallback opens', (tester) async {
    final repo = _FakeUserRepo();
    repo.users['alex'] = const AppUser(
      uid: 'alex',
      email: 'alex@example.com',
      paymentMethod: 'venmo',
      paymentHandle: 'alex_v',
    );
    final launcher = _RecordingLauncher()..returnValue = false;
    final fallback = _FallbackRecorder();
    final controller = _build(
      userRepo: repo,
      launcher: launcher,
      fallback: fallback,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final ctx = tester.element(find.byType(Scaffold));
    await controller.handleSettleUp(ctx, _debt);

    expect(launcher.launched, hasLength(1));
    expect(fallback.calls, hasLength(1));
  });

  testWidgets('launcher throws → caught; fallback opens', (tester) async {
    final repo = _FakeUserRepo();
    repo.users['alex'] = const AppUser(
      uid: 'alex',
      email: 'alex@example.com',
      paymentMethod: 'venmo',
      paymentHandle: 'alex_v',
    );
    final launcher = _RecordingLauncher()
      ..throwOnLaunch = StateError('launch boom');
    final fallback = _FallbackRecorder();
    final controller = _build(
      userRepo: repo,
      launcher: launcher,
      fallback: fallback,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final ctx = tester.element(find.byType(Scaffold));
    await controller.handleSettleUp(ctx, _debt);

    expect(fallback.calls, hasLength(1));
  });

  testWidgets(
    'userRepository.getUser throws → snackbar + fallback opens without counterparty',
    (tester) async {
      final repo = _FakeUserRepo()..throwOnGet = StateError('contact boom');
      final launcher = _RecordingLauncher();
      final fallback = _FallbackRecorder();
      final controller = _build(
        userRepo: repo,
        launcher: launcher,
        fallback: fallback,
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      final ctx = tester.element(find.byType(Scaffold));
      await controller.handleSettleUp(ctx, _debt);

      expect(launcher.launched, isEmpty);
      expect(fallback.calls, hasLength(1));
      expect(fallback.calls.single.counterparty, isNull);
      // Snackbar visible after a pump.
      await tester.pump();
      expect(find.text('Could not load contact info'), findsOneWidget);
    },
  );
}
