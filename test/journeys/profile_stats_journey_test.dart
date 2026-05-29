import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/profile/presentation/profile_screen.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

import '../app/features/auth/fake_auth_service.dart';

/// Forces an `Authenticated` state without going through Firebase auth.
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._user)
    : super(authRepository: _UnusedAuthRepository());
  final AppUser _user;

  @override
  AuthState build() => Authenticated(_user);
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Auth not used in test harness');
}

/// Profile stats journey: seed events + tasks + ledger overrides, open
/// Profile, assert `StatTriplet` renders the right counts.
void main() {
  testWidgets(
    'profile stats — three cells render counts from their providers',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const user = AppUser(
        uid: 'uid-1',
        email: 'alex@example.com',
        displayName: 'Alex',
        emailVerified: true,
      );
      const events = [
        EventModel(
          id: 'evt-a',
          title: 'Tahoe Trip',
          creatorId: 'uid-1',
          memberIds: ['uid-1'],
        ),
        EventModel(
          id: 'evt-b',
          title: 'Project Sync',
          creatorId: 'uid-1',
          memberIds: ['uid-1'],
        ),
      ];
      const tasks = [
        TaskModel(
          id: 't-1',
          eventId: 'evt-a',
          title: 'Book cabin',
          assigneeId: 'uid-1',
        ),
        TaskModel(
          id: 't-2',
          eventId: 'evt-a',
          title: 'Buy snacks',
          assigneeId: 'uid-1',
        ),
        TaskModel(
          id: 't-3',
          eventId: 'evt-b',
          title: 'Write spec',
          assigneeId: 'uid-1',
        ),
      ];
      const ledger = LedgerSummary(
        totalOwedToYou: 0,
        totalYouOwe: 75,
        debts: [],
        recentExpenses: [],
      );

      final fake = FakeAuthService();
      addTearDown(fake.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _StubAuthNotifier(user)),
            dashboardEventsProvider.overrideWith((ref) => Stream.value(events)),
            taskListProvider.overrideWith((ref, eventId) {
              return switch (eventId) {
                'evt-a' => Stream.value(
                  tasks.where((t) => t.eventId == 'evt-a').toList(),
                ),
                'evt-b' => Stream.value(
                  tasks.where((t) => t.eventId == 'evt-b').toList(),
                ),
                _ => Stream.value(const <TaskModel>[]),
              };
            }),
            globalBalanceLedgerProvider.overrideWith(
              (ref, uid) => const AsyncValue.data(ledger),
            ),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      // Bounded pumps: Lottie loops in empty states, Firestore mirrors etc.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // StatTriplet container is keyed; the three cells render numeric
      // values from their respective providers.
      expect(find.byKey(const Key('profile.statTriplet')), findsOneWidget);
      // Events count = 2 (from dashboardEventsProvider).
      expect(find.text('2'), findsOneWidget);
      // Tasks count = 3 (from myAssignedTasksProvider).
      expect(find.text('3'), findsOneWidget);
      // Owed = "$75" (from globalBalanceLedgerProvider.totalYouOwe).
      expect(find.text(r'$75'), findsOneWidget);
      // Labels.
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Owed'), findsOneWidget);

      // Unmount cleanly before invariants run.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
