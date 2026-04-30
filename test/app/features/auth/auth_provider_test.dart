import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';

import 'fake_auth_service.dart';

void main() {
  late FakeAuthService fakeAuthService;
  late AuthRepository repository;
  late ProviderContainer container;
  late NotifierProvider<AuthNotifier, AuthState> authProvider;

  const testAuthUser = AuthUser(
    uid: 'uid-123',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  setUp(() {
    fakeAuthService = FakeAuthService();
    repository = AuthRepository(authService: fakeAuthService);

    authProvider = NotifierProvider<AuthNotifier, AuthState>(
      () => AuthNotifier(authRepository: repository),
    );

    container = ProviderContainer();
    // Initialize the provider to trigger build()
    container.read(authProvider);
  });

  tearDown(() {
    container.dispose();
    fakeAuthService.dispose();
  });

  test('starts as unauthenticated', () {
    final state = container.read(authProvider);
    expect(state, isA<Unauthenticated>());
  });

  test('becomes authenticated on successful sign-in', () async {
    fakeAuthService.nextResult = const AuthSuccess(testAuthUser);

    await container
        .read(authProvider.notifier)
        .signInWithEmail(email: 'test@example.com', password: 'correct');

    final state = container.read(authProvider);
    expect(state, isA<Authenticated>());
    final authenticated = state as Authenticated;
    expect(authenticated.user.uid, equals('uid-123'));
  });

  test('becomes error on failed sign-in', () async {
    fakeAuthService.nextResult = const AuthResultFailure('Invalid credentials');

    await container
        .read(authProvider.notifier)
        .signInWithEmail(email: 'test@example.com', password: 'wrong');

    final state = container.read(authProvider);
    expect(state, isA<AuthError>());
  });

  test('resendVerificationEmail invokes the service exactly once when '
      'authenticated', () async {
    fakeAuthService.setCurrentUser(testAuthUser);
    await Future<void>.delayed(Duration.zero); // let stream propagate
    // Force-rebuild so we observe the post-stream state.
    container.read(authProvider);

    await container.read(authProvider.notifier).resendVerificationEmail();

    expect(fakeAuthService.sendEmailVerificationCalls, equals(1));
  });

  test(
    'resendVerificationEmail no-ops when the user is unauthenticated',
    () async {
      await container.read(authProvider.notifier).resendVerificationEmail();
      expect(fakeAuthService.sendEmailVerificationCalls, equals(0));
    },
  );

  test(
    'reloadCurrentUser delegates to the service when authenticated',
    () async {
      fakeAuthService.setCurrentUser(testAuthUser);
      await Future<void>.delayed(Duration.zero);
      container.read(authProvider);

      await container.read(authProvider.notifier).reloadCurrentUser();

      expect(fakeAuthService.reloadCalls, equals(1));
    },
  );
}
