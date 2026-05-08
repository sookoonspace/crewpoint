import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

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
}

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
