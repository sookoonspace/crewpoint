import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/budget/presentation/event_budget_page.dart';
import 'package:crewpoint_app/app/features/chat/presentation/event_chat_page.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/member_management_screen.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/event_task_detail_page.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/event_tasks_page.dart';

import '../../../app/features/auth/fake_auth_service.dart';

Widget _wrapWithProviders(GoRouter router, {List<EventModel>? eventsForRoute}) {
  final fakeAuthService = FakeAuthService();
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(
        () => AuthNotifier(
          authRepository: AuthRepository(authService: fakeAuthService),
        ),
      ),
      if (eventsForRoute != null)
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(eventsForRoute),
        ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Bounded pump — used when landing on a screen that renders the
/// `EmptyStatePlaceholder` lottie animation (lottie loops forever, so
/// `pumpAndSettle` would hang).
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('redirects unauthenticated user to auth gate', (tester) async {
    final router = createRouter(
      isOnboardingComplete: () => true,
      isAuthenticated: () => false,
    );

    await tester.pumpWidget(_wrapWithProviders(router));
    await tester.pumpAndSettle();

    expect(find.text('CrewPoint'), findsOneWidget);
  });

  testWidgets('redirects authenticated user past auth to dashboard', (
    tester,
  ) async {
    final router = createRouter(
      isOnboardingComplete: () => true,
      isAuthenticated: () => true,
    );

    await tester.pumpWidget(_wrapWithProviders(router));
    await _pumpFrames(tester);

    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('redirects to onboarding when not complete', (tester) async {
    final router = createRouter(
      isOnboardingComplete: () => false,
      isAuthenticated: () => false,
    );

    await tester.pumpWidget(_wrapWithProviders(router));
    await tester.pumpAndSettle();

    expect(find.text('CrewPoint'), findsOneWidget);
  });

  testWidgets(
    'unmatched route renders the friendly error screen + Go home button',
    (tester) async {
      final router = createRouter(
        isOnboardingComplete: () => true,
        isAuthenticated: () => true,
        initialLocation: '/this-route-does-not-exist',
      );

      await tester.pumpWidget(_wrapWithProviders(router));
      await tester.pumpAndSettle();

      // Friendly fallback (NOT the default GoRouter "no route" page).
      expect(find.byKey(const Key('router.error.goHome')), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);

      await tester.tap(find.byKey(const Key('router.error.goHome')));
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('dashboard.action.createEvent')),
        findsOneWidget,
        reason: 'tapping Go home navigates to the dashboard',
      );
    },
  );

  group('event routes resolve by ID', () {
    const event = EventModel(
      id: 'evt-1',
      title: 'Tahoe Trip',
      creatorId: 'owner-1',
      memberIds: ['owner-1'],
    );

    /// Each row: route URL → matcher for the resolved screen widget. Six
    /// event URLs total — covers Stage 1's parameterized resolution
    /// requirement. Using type matchers (not text) so the test stays
    /// stable across copy changes.
    final routes = <(String label, String url, Finder marker)>[
      ('parent', '/dashboard/event/evt-1', find.byType(EventDashboardScreen)),
      (
        'members',
        '/dashboard/event/evt-1/members',
        find.byType(MemberManagementScreen),
      ),
      ('budget', '/dashboard/event/evt-1/budget', find.byType(EventBudgetPage)),
      ('chat', '/dashboard/event/evt-1/chat', find.byType(EventChatPage)),
      ('tasks', '/dashboard/event/evt-1/tasks', find.byType(EventTasksPage)),
      (
        'task detail',
        '/dashboard/event/evt-1/tasks/task-1',
        find.byType(EventTaskDetailPage),
      ),
    ];

    for (final route in routes) {
      testWidgets('resolves the ${route.$1} sub-route', (tester) async {
        final router = createRouter(
          isOnboardingComplete: () => true,
          isAuthenticated: () => true,
          initialLocation: route.$2,
        );

        await tester.pumpWidget(
          _wrapWithProviders(router, eventsForRoute: const [event]),
        );
        await tester.pumpAndSettle();

        expect(route.$3, findsWidgets);
        expect(find.byKey(const Key('event.notFound.back')), findsNothing);
      });
    }

    testWidgets(
      'missing-id at the parent route renders the friendly fallback after grace',
      (tester) async {
        final router = createRouter(
          isOnboardingComplete: () => true,
          isAuthenticated: () => true,
          initialLocation: '/dashboard/event/does-not-exist',
        );

        await tester.pumpWidget(
          _wrapWithProviders(router, eventsForRoute: const []),
        );
        await tester.pumpAndSettle();
        // Pattern A — advance past the 750ms cold-start grace.
        await tester.pump(const Duration(milliseconds: 750));
        await tester.pump();

        expect(find.byKey(const Key('event.notFound.back')), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Back to events from the fallback lands on the dashboard',
      (tester) async {
        final router = createRouter(
          isOnboardingComplete: () => true,
          isAuthenticated: () => true,
          initialLocation: '/dashboard/event/does-not-exist',
        );

        await tester.pumpWidget(
          _wrapWithProviders(router, eventsForRoute: const []),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 750));
        await tester.pump();

        await tester.tap(find.byKey(const Key('event.notFound.back')));
        // Landing on the dashboard with no events renders the
        // EmptyStatePlaceholder lottie — bounded pumps instead of settle.
        await _pumpFrames(tester);

        expect(
          find.byKey(const Key('dashboard.action.createEvent')),
          findsOneWidget,
        );
      },
    );
  });
}
