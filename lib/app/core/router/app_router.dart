import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/event_guard.dart';
import 'package:crewpoint_app/app/core/widgets/responsive_shell.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/email_unverified_banner.dart';
import 'package:crewpoint_app/app/features/profile/presentation/edit_profile_screen.dart';
import 'package:crewpoint_app/app/features/profile/presentation/privacy_dashboard_screen.dart';
import 'package:crewpoint_app/app/features/profile/presentation/profile_screen.dart';
import 'package:crewpoint_app/app/features/auth/presentation/auth_gate_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/create_event_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/edit_event_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/member_management_screen.dart';
import 'package:crewpoint_app/app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:crewpoint_app/app/features/budget/presentation/budget_ledger_screen.dart';
import 'package:crewpoint_app/app/features/budget/presentation/event_budget_page.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_inbox_screen.dart';
import 'package:crewpoint_app/app/features/chat/presentation/event_chat_page.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/event_task_detail_page.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/event_tasks_page.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/my_tasks_screen.dart';

/// Route paths.
abstract final class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String tasks = '/tasks';
  static const String chat = '/chat';
  static const String budget = '/budget';
  static const String profile = '/profile';
  static const String privacyDashboard = '/profile/privacy-dashboard';
}

/// Creates the app router.
///
/// [isOnboardingComplete] / [isAuthenticated] are called fresh on every
/// redirect evaluation so the router can be constructed ONCE and refreshed
/// in place when auth or onboarding state changes — instead of recreating
/// the router on every Riverpod-driven `MyApp.build` (the old pattern,
/// which destroyed modal routes mid-deletion and reproduced the GoRouter
/// "code-blob + Home" page).
///
/// [refreshListenable] (optional) — if provided, GoRouter re-runs the
/// redirect chain every time the listenable notifies. Wire it to a
/// `ChangeNotifier` that fires on auth/onboarding flips.
///
/// [onRouteChanged] (optional) is called with the matched location on each
/// navigation — used to keep `currentRouteProvider` in sync.
///
/// [initialLocation] (optional) overrides the default landing path; tests
/// use this to pump unmatched routes against [errorBuilder].
GoRouter createRouter({
  required bool Function() isOnboardingComplete,
  required bool Function() isAuthenticated,
  Listenable? refreshListenable,
  void Function(String location)? onRouteChanged,
  String initialLocation = AppRoutes.dashboard,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    errorBuilder: (_, state) => _RouterErrorScreen(
      attemptedLocation: state.uri.toString(),
      error: state.error?.toString(),
    ),
    redirect: (context, state) {
      final location = state.matchedLocation;
      onRouteChanged?.call(location);

      final onboardingDone = isOnboardingComplete();
      final authed = isAuthenticated();

      if (!onboardingDone && location != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }

      if (onboardingDone && location == AppRoutes.onboarding) {
        return authed ? AppRoutes.dashboard : AppRoutes.auth;
      }

      if (!authed &&
          location != AppRoutes.auth &&
          location != AppRoutes.onboarding) {
        return AppRoutes.auth;
      }

      if (authed && location == AppRoutes.auth) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, _) => Consumer(
          builder: (context, ref, _) => OnboardingScreen(
            onComplete: () {
              ref.read(onboardingProvider.notifier).completeOnboarding();
            },
          ),
        ),
      ),
      GoRoute(path: AppRoutes.auth, builder: (_, _) => const AuthGateScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => Consumer(
          builder: (_, ref, _) => ResponsiveShell(
            currentIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            onSignOut: () => ref.read(authProvider.notifier).signOut(),
            body: Column(
              children: [
                const EmailUnverifiedBanner(),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, _) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (_, _) => const CreateEventScreen(),
                  ),
                  GoRoute(
                    path: 'event/:eventId',
                    builder: (_, state) => EventGuard(
                      eventId: _resolveEventId(state),
                      child: (event) => EventDashboardScreen(event: event),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => EventGuard(
                          eventId: _resolveEventId(state),
                          child: (event) => Consumer(
                            builder: (_, ref, _) =>
                                _EditEventRouteScreen(event: event),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'members',
                        builder: (_, state) => EventGuard(
                          eventId: _resolveEventId(state),
                          child: (event) => Consumer(
                            builder: (_, ref, _) => MemberManagementScreen(
                              event: event,
                              currentUserId:
                                  ref.watch(currentUserIdProvider) ?? '',
                            ),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'budget',
                        builder: (_, state) => EventGuard(
                          eventId: _resolveEventId(state),
                          child: (event) => EventBudgetPage(event: event),
                        ),
                      ),
                      GoRoute(
                        path: 'chat',
                        builder: (_, state) => EventGuard(
                          eventId: _resolveEventId(state),
                          child: (event) => EventChatPage(event: event),
                        ),
                      ),
                      GoRoute(
                        path: 'tasks',
                        builder: (_, state) => EventGuard(
                          eventId: _resolveEventId(state),
                          child: (event) => EventTasksPage(event: event),
                        ),
                        routes: [
                          GoRoute(
                            path: ':taskId',
                            builder: (_, state) {
                              final taskId =
                                  state.pathParameters['taskId'] ?? '';
                              return EventGuard(
                                eventId: _resolveEventId(state),
                                child: (event) => EventTaskDetailPage(
                                  event: event,
                                  taskId: taskId,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tasks,
                builder: (_, _) => const MyTasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (_, _) => const ChatInboxScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.budget,
                builder: (_, _) => const BudgetLedgerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, _) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'privacy-dashboard',
                    builder: (_, _) => const PrivacyDashboardScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Extracts the `eventId` for an event-related route. Prefers
/// `state.pathParameters['eventId']`; falls back to a regex parse of
/// `state.matchedLocation` for the (uncommon) case where GoRouter doesn't
/// propagate the parent path param into deeply nested route builders.
/// Returns the empty string for a malformed URL — `EventGuard` then
/// renders the fallback immediately.
String _resolveEventId(GoRouterState state) {
  final fromParam = state.pathParameters['eventId'];
  if (fromParam != null && fromParam.isNotEmpty) return fromParam;
  final match = RegExp(r'/event/([^/]+)').firstMatch(state.matchedLocation);
  return match?.group(1) ?? '';
}

/// Friendly fallback for unmatched routes. Replaces GoRouter's default
/// `_DefaultRouterError` (the "route blob + Home link" page the user
/// was hitting after the broken account-delete flow).
class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen({this.attemptedLocation, this.error});

  final String? attemptedLocation;
  final String? error;

  @override
  Widget build(BuildContext context) {
    // Log the failing match so the cause is visible in `flutter logs` /
    // Xcode console / Cloud Logging when the screen surfaces in
    // production. Diagnostic only — does not affect render.
    if (attemptedLocation != null) {
      developer.log(
        'GoRouter unmatched route: $attemptedLocation '
        '(error: ${error ?? "no-error-object"})',
        name: 'router',
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.lg,
              children: [
                const Icon(
                  AppIcons.errorCompass,
                  size: AppSizes.iconHero,
                  color: AppColors.sage,
                ),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  "We couldn't find that page.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (attemptedLocation != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tried: $attemptedLocation',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.darkGrey,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton.icon(
                  key: const Key('router.error.goHome'),
                  onPressed: () => context.go(AppRoutes.dashboard),
                  icon: const Icon(AppIcons.homeOutlined),
                  label: const Text('Go home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper screen for the `event/:eventId/edit` route. Pushes the edit
/// form, calls `eventRepositoryProvider.updateEvent` on submit, surfaces
/// terracotta snackbar on failure.
class _EditEventRouteScreen extends ConsumerWidget {
  const _EditEventRouteScreen({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EditEventScreen(
      initial: event,
      onSubmit: (updated) async {
        final ok = await ref.read(eventRepositoryProvider).updateEvent(updated);
        if (!context.mounted) return;
        if (ok) {
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save event'),
              backgroundColor: AppColors.terracotta,
            ),
          );
        }
      },
    );
  }
}
