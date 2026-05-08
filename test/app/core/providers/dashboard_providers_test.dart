import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  group('currentUserIdProvider', () {
    test('returns the uid when auth state is Authenticated', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _StubAuthNotifier(
              const AppUser(uid: 'uid-42', email: 'a@example.com'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserIdProvider), 'uid-42');
    });

    test('returns null when auth state is Unauthenticated', () {
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserIdProvider), isNull);
    });

    test('returns null for AuthInitial / AuthLoading / AuthError states', () {
      for (final notifierFactory in <AuthNotifier Function()>[
        _InitialNotifier.new,
        _LoadingNotifier.new,
      ]) {
        final container = ProviderContainer(
          overrides: [authProvider.overrideWith(notifierFactory)],
        );
        addTearDown(container.dispose);
        expect(container.read(currentUserIdProvider), isNull);
      }
    });
  });

  // dashboardEventsProvider's behavior is exercised end-to-end by the
  // dashboard widget test + the create-event journey test. The signed-out
  // path is a one-line `if (uid == null) return Stream.value([])`; the
  // signed-in path goes through the EventRepository which has its own unit
  // tests. Wrapping either in a ProviderContainer adds plumbing without
  // independent signal.

  group('eventByIdProvider', () {
    test('returns the matching event from a data emission', () async {
      const target = EventModel(
        id: 'evt-1',
        title: 'Tahoe Trip',
        creatorId: 'uid-1',
      );
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [
              target,
              EventModel(id: 'evt-2', title: 'Other', creatorId: 'uid-1'),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Keep the StreamProvider alive while we wait for its first emission.
      addTearDown(container.listen(dashboardEventsProvider, (_, _) {}).close);
      await _pumpEvents();

      expect(container.read(eventByIdProvider('evt-1')), target);
    });

    test('returns null when the id is absent from the data emission', () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [
              EventModel(id: 'evt-1', title: 'A', creatorId: 'uid-1'),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(container.listen(dashboardEventsProvider, (_, _) {}).close);
      await _pumpEvents();

      expect(container.read(eventByIdProvider('does-not-exist')), isNull);
    });

    test('returns null while the underlying provider is still loading', () {
      // No await/listen → provider stays in AsyncLoading.
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => const Stream<List<EventModel>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(eventByIdProvider('evt-1')), isNull);
    });
  });
}

/// Lets the in-flight stream subscription deliver its first emission so the
/// provider transitions out of `AsyncLoading`. Riverpod 3's StreamProvider
/// schedules the subscription on a microtask; one event-loop tick is
/// sufficient.
Future<void> _pumpEvents() => Future<void>.delayed(Duration.zero);

/// Forces an `Authenticated` state without touching real Firebase auth.
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._user)
    : super(authRepository: _UnusedAuthRepository());
  final AppUser _user;

  @override
  AuthState build() => Authenticated(_user);
}

class _UnauthNotifier extends AuthNotifier {
  _UnauthNotifier() : super(authRepository: _UnusedAuthRepository());

  @override
  AuthState build() => const Unauthenticated();
}

class _InitialNotifier extends AuthNotifier {
  _InitialNotifier() : super(authRepository: _UnusedAuthRepository());

  @override
  AuthState build() => const AuthInitial();
}

class _LoadingNotifier extends AuthNotifier {
  _LoadingNotifier() : super(authRepository: _UnusedAuthRepository());

  @override
  AuthState build() => const AuthLoading();
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Auth not exercised in test');
}
