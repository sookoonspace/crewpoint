import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/data/pay_link_builder.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/budget_ledger_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

import '../robots/budget_ledger_robot.dart';

class _RecordingLauncher implements IUrlLauncher {
  final List<Uri> launched = [];
  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return true;
  }
}

class _FakeUserRepo implements IUserRepository {
  _FakeUserRepo(this._user);
  final AppUser _user;

  @override
  Future<AppUser?> getUser(String uid) async => _user;

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

  @override
  Future<NotificationPrefs> getNotificationPrefs(String uid) async =>
      const NotificationPrefs();

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required NotificationPrefs prefs,
  }) async => throw UnimplementedError();
}

const _event = EventModel(
  id: 'evt-1',
  title: 'Tahoe Trip',
  creatorId: 'me',
  memberIds: ['me', 'alex'],
  currency: 'USD',
);

/// I owe alex $45: alex paid $90, split 50/50.
final _expense = ExpenseModel(
  id: 'exp-1',
  eventId: 'evt-1',
  payerId: 'alex',
  amount: 90,
  splits: const [
    ExpenseSplit(userId: 'alex', amount: 45),
    ExpenseSplit(userId: 'me', amount: 45),
  ],
  createdAt: DateTime(2026, 5, 14),
);

Future<void> _pumpLedger(
  WidgetTester tester, {
  required _RecordingLauncher launcher,
  required _FakeUserRepo userRepo,
}) async {
  // Tiny GoRouter so context.push from the fallback sheet's "Mark paid"
  // link can land on a stub destination.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const BudgetLedgerScreen()),
      GoRoute(
        path: '/dashboard/event/:eventId/budget',
        builder: (_, _) => const Scaffold(body: Text('event budget')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'me'),
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [_event]),
        ),
        expenseListProvider.overrideWith(
          (ref, eventId) => Stream.value([_expense]),
        ),
        urlLauncherProvider.overrideWithValue(launcher),
        userRepositoryProvider.overrideWithValue(userRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  testWidgets(
    'Settle Up venmo path — captures Venmo deep link URI matching PayLinkBuilder',
    (tester) async {
      final launcher = _RecordingLauncher();
      final repo = _FakeUserRepo(
        const AppUser(
          uid: 'alex',
          email: 'alex@example.com',
          displayName: 'Alex',
          paymentMethod: 'venmo',
          paymentHandle: 'alex_v',
        ),
      );

      final robot = BudgetLedgerRobot(tester);
      await _pumpLedger(tester, launcher: launcher, userRepo: repo);
      await robot.pumpFrames();

      robot.expectDebtRow('alex', 'evt-1');
      await robot.tapSettleUp('alex', 'evt-1');

      expect(launcher.launched, hasLength(1));
      expect(
        launcher.launched.single,
        PayLinkBuilder.venmo(
          handle: 'alex_v',
          amount: 45,
          note: 'Tahoe Trip settle-up',
        ),
      );
      robot.expectFallbackSheetGone();
    },
  );

  testWidgets(
    'Settle Up cash path — no launch; fallback sheet opens; Copy Amount works; Mark Paid pops + navigates',
    (tester) async {
      final launcher = _RecordingLauncher();
      final repo = _FakeUserRepo(
        const AppUser(
          uid: 'alex',
          email: 'alex@example.com',
          displayName: 'Alex',
          paymentMethod: 'cash',
        ),
      );

      final robot = BudgetLedgerRobot(tester);
      await _pumpLedger(tester, launcher: launcher, userRepo: repo);
      await robot.pumpFrames();

      await robot.tapSettleUp('alex', 'evt-1');
      // Sheet visible; no launch.
      robot.expectFallbackSheetVisible();
      expect(launcher.launched, isEmpty);

      // Copy Amount + Mark Paid both work.
      await robot.tapFallbackCopyAmount();
      await robot.tapFallbackMarkPaid();
      await tester.pumpAndSettle();

      // Sheet popped + landed on stub destination.
      robot.expectFallbackSheetGone();
      expect(find.text('event budget'), findsOneWidget);
    },
  );
}
