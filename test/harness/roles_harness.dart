import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/device_timezone.dart';
import 'package:crewpoint_app/app/core/widgets/event_guard.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/member_management_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/crews_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/member_detail_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_editor_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/roles_screen.dart';

import 'fake_member_calls.dart';
import 'member_docs.dart';

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

/// The Members, Member detail, Roles and Role editor screens over a fake
/// Firestore, with [FakeMemberCalls] writing what the server would.
///
/// The event `evt` is published, owned by `owner`, with `sam` as a
/// Participant. [currentUser] chooses who is signed in.
class RolesHarness {
  RolesHarness({required String signedInAs, this.initialLocation})
    : currentUser = AppUser(uid: signedInAs, email: '$signedInAs@example.com'),
      firestore = FakeFirebaseFirestore(),
      database = AppDatabase(NativeDatabase.memory()) {
    calls = FakeMemberCalls(firestore: firestore);
  }

  static const eventId = 'evt';
  static const names = {'owner': 'Olivia', 'sam': 'Sam', 'ana': 'Ana'};

  final AppUser currentUser;
  final FakeFirebaseFirestore firestore;
  final AppDatabase database;
  final String? initialLocation;
  late final FakeMemberCalls calls;

  /// Seeds the event and a member document for each person, with these roles.
  Future<void> seed({
    Map<String, List<String>> roles = const {
      'owner': ['owner'],
      'sam': ['participant'],
    },
  }) async {
    final presets = resolveRoles(RoleCatalogue.current, const {});
    for (final entry in roles.entries) {
      await firestore.doc('events/$eventId/members/${entry.key}').set({
        'uid': entry.key,
        'roleIds': entry.value,
        'permissions': computePermissions(entry.value, presets),
      });
    }
    await firestore.doc('events/$eventId').set({
      'id': eventId,
      'title': 'Convention',
      'creatorId': 'owner',
      'adminIds': [
        for (final e in roles.entries)
          if (e.value.any(
            (r) => const {'owner', 'coOwner', 'admin'}.contains(r),
          ))
            e.key,
      ],
      'memberIds': roles.keys.toList(),
      'memberCount': roles.length,
      'status': 'published',
      'currency': 'USD',
    });
  }

  late final GoRouter router = GoRouter(
    initialLocation: initialLocation ?? '/dashboard/event/$eventId/members',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('dashboard')),
        routes: [
          GoRoute(
            path: 'event/:eventId',
            builder: (_, _) => const Scaffold(body: Text('event')),
            routes: [
              GoRoute(
                path: 'members',
                builder: (_, state) => EventGuard(
                  eventId: eventId,
                  child: (event) => MemberManagementScreen(
                    event: event,
                    currentUserId: currentUser.uid,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':uid',
                    builder: (_, state) => EventGuard(
                      eventId: eventId,
                      child: (event) => MemberDetailScreen(
                        event: event,
                        uid: state.pathParameters['uid']!,
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'crews',
                builder: (_, _) => EventGuard(
                  eventId: eventId,
                  child: (event) => CrewsScreen(event: event),
                ),
              ),
              GoRoute(
                path: 'roles',
                builder: (_, _) => EventGuard(
                  eventId: eventId,
                  child: (event) => RolesScreen(event: event),
                ),
                routes: [
                  GoRoute(
                    path: ':roleId',
                    builder: (_, state) => EventGuard(
                      eventId: eventId,
                      child: (event) => RoleEditorScreen(
                        event: event,
                        roleId: state.pathParameters['roleId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Widget buildApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        firestoreProvider.overrideWithValue(firestore),
        membershipsSourceProvider.overrideWithValue(fakeMemberships(firestore)),
        deviceTimezoneProvider.overrideWithValue(
          const LocalNameDeviceTimezone(),
        ),
        authProvider.overrideWith(() => _StubAuthNotifier(currentUser)),
        memberCallsProvider.overrideWithValue(calls),
        ...overrides,
        usersByIdProvider.overrideWith(
          (ref, key) async => {
            for (final uid in key.split(','))
              if (names[uid] != null)
                uid: AppUser(
                  uid: uid,
                  email: '$uid@example.com',
                  displayName: names[uid],
                ),
          },
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }
}
