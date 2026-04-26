import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_shell.dart';
import 'package:crewpoint_app/app/features/profile/presentation/edit_profile_screen.dart';
import 'package:crewpoint_app/app/features/profile/presentation/profile_screen.dart';
import 'package:crewpoint_app/app/features/auth/presentation/auth_gate_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/create_event_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/member_management_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/onboarding/presentation/onboarding_screen.dart';
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
}

/// Creates the app router.
/// [isOnboardingComplete] and [isAuthenticated] drive redirects.
GoRouter createRouter({
  required bool isOnboardingComplete,
  required bool isAuthenticated,
}) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (!isOnboardingComplete && location != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }

      if (isOnboardingComplete && location == AppRoutes.onboarding) {
        return isAuthenticated ? AppRoutes.dashboard : AppRoutes.auth;
      }

      if (!isAuthenticated &&
          location != AppRoutes.auth &&
          location != AppRoutes.onboarding) {
        return AppRoutes.auth;
      }

      if (isAuthenticated && location == AppRoutes.auth) {
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
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
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
                          return MemberManagementScreen(
                            event: event,
                            currentUserId: '', // TODO: get from auth
                          );
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
