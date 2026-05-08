import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/event_guard.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/create_event_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';

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
      throw UnimplementedError('Auth not exercised in test');
}

/// Drives the create-event journey end-to-end. Provides:
/// - `FakeFirebaseFirestore` for the Firestore boundary,
/// - in-memory Drift DB for the mirror,
/// - a minimal `GoRouter` covering `/dashboard` + `/dashboard/create`,
/// - `_StubAuthNotifier` so the dashboard renders signed-in state.
class DashboardJourneyHarness {
  DashboardJourneyHarness({required this.currentUser})
    : firestore = FakeFirebaseFirestore(),
      database = AppDatabase(NativeDatabase.memory());

  final AppUser currentUser;
  final FakeFirebaseFirestore firestore;
  final AppDatabase database;

  late final GoRouter _router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const DashboardScreen(),
        routes: [
          GoRoute(path: 'create', builder: (_, _) => const CreateEventScreen()),
          GoRoute(
            path: 'event/:eventId',
            builder: (_, state) => EventGuard(
              eventId: state.pathParameters['eventId'] ?? '',
              child: (event) => EventDashboardScreen(event: event),
            ),
          ),
        ],
      ),
    ],
  );

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        firestoreProvider.overrideWithValue(firestore),
        authProvider.overrideWith(() => _StubAuthNotifier(currentUser)),
      ],
      child: MaterialApp.router(routerConfig: _router),
    );
  }
}
