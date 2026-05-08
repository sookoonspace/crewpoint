import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/responsive_shell.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/email_unverified_banner.dart';
import 'package:crewpoint_app/app/features/profile/presentation/edit_profile_screen.dart';
import 'package:crewpoint_app/app/features/profile/presentation/privacy_dashboard_screen.dart';
import 'package:crewpoint_app/app/features/profile/presentation/profile_screen.dart';
import 'package:crewpoint_app/app/features/auth/presentation/auth_gate_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/create_event_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/member_management_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:crewpoint_app/app/features/budget/presentation/event_budget_page.dart';
import 'package:crewpoint_app/app/features/chat/presentation/event_chat_page.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/event_task_detail_page.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/event_tasks_page.dart';

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
                    builder: (context, state) {
                      final event = state.extra as EventModel?;
                      if (event == null) {
                        return const _PlaceholderScreen(
                          title: 'Event not found',
                        );
                      }
                      return EventDashboardScreen(event: event);
                    },
                    routes: [
                      GoRoute(
                        path: 'members',
                        builder: (context, state) {
                          final event = state.extra as EventModel?;
                          if (event == null) {
                            return const _PlaceholderScreen(title: 'Members');
                          }
                          return Consumer(
                            builder: (_, ref, _) => MemberManagementScreen(
                              event: event,
                              currentUserId:
                                  ref.watch(currentUserIdProvider) ?? '',
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'budget',
                        builder: (context, state) {
                          final event = state.extra as EventModel?;
                          if (event == null) {
                            return const _PlaceholderScreen(title: 'Budget');
                          }
                          return EventBudgetPage(event: event);
                        },
                      ),
                      GoRoute(
                        path: 'chat',
                        builder: (context, state) {
                          final event = state.extra as EventModel?;
                          if (event == null) {
                            return const _PlaceholderScreen(title: 'Chat');
                          }
                          return EventChatPage(event: event);
                        },
                      ),
                      GoRoute(
                        path: 'tasks',
                        builder: (context, state) {
                          final event = state.extra as EventModel?;
                          if (event == null) {
                            return const _PlaceholderScreen(title: 'Tasks');
                          }
                          return EventTasksPage(event: event);
                        },
                        routes: [
                          GoRoute(
                            path: ':taskId',
                            builder: (context, state) {
                              final event = state.extra as EventModel?;
                              final taskId = state.pathParameters['taskId'];
                              if (event == null || taskId == null) {
                                return const _PlaceholderScreen(title: 'Task');
                              }
                              return EventTaskDetailPage(
                                event: event,
                                taskId: taskId,
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
                builder: (_, _) => const _PlaceholderScreen(title: 'Tasks'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (_, _) => const _PlaceholderScreen(title: 'Chat'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.budget,
                builder: (_, _) => const _PlaceholderScreen(title: 'Budget'),
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

/// Temporary placeholder until real screens are built.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
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
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.lg,
              children: [
                const Icon(
                  Icons.compass_calibration_outlined,
                  size: 64,
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
                  icon: const Icon(Icons.home_outlined),
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
