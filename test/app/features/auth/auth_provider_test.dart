import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';

import 'fake_auth_service.dart';
import 'fake_user_repository.dart';

void main() {
  late FakeAuthService fakeAuthService;
  late AuthRepository repository;
  late FakeUserRepository fakeUserRepository;
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
    fakeUserRepository = FakeUserRepository();

    authProvider = NotifierProvider<AuthNotifier, AuthState>(
      () => AuthNotifier(
        authRepository: repository,
        userRepository: fakeUserRepository,
      ),
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

  group('user doc creation on auth state change', () {
    test('listener calls createUserIfNotExists exactly once with provider '
        'displayName when stream emits a non-null user', () async {
      const richUser = AuthUser(
        uid: 'uid-google',
        email: 'jane@gmail.com',
        displayName: '  Jane Doe  ', // surrounding whitespace must be trimmed
        photoUrl: 'https://lh3.googleusercontent.com/a/abc',
        providerIds: ['google.com'],
      );
      fakeAuthService.nextResult = const AuthSuccess(richUser);

      await container
          .read(authProvider.notifier)
          .signInWithEmail(email: 'jane@gmail.com', password: 'pw');
      await Future<void>.delayed(Duration.zero); // let unawaited future run

      expect(fakeUserRepository.createCalls, hasLength(1));
      final call = fakeUserRepository.createCalls.single;
      expect(call.uid, equals('uid-google'));
      expect(call.email, equals('jane@gmail.com'));
      expect(call.displayName, equals('Jane Doe'));
      expect(call.photoUrl, equals('https://lh3.googleusercontent.com/a/abc'));
      expect(call.providerIds, equals(['google.com']));
    });

    test('falls back to deriveDisplayNameFromEmail when provider supplies '
        'null displayName (Apple subsequent login)', () async {
      const appleUser = AuthUser(
        uid: 'uid-apple',
        email: 'apple+sub@privaterelay.appleid.com',
        // displayName intentionally omitted (null) — Apple's behaviour
        // on subsequent logins.
        providerIds: ['apple.com'],
      );
      fakeAuthService.nextResult = const AuthSuccess(appleUser);

      await container
          .read(authProvider.notifier)
          .signInWithEmail(
            email: 'apple+sub@privaterelay.appleid.com',
            password: 'pw',
          );
      await Future<void>.delayed(Duration.zero);

      expect(fakeUserRepository.createCalls, hasLength(1));
      // 'apple+sub@...' → strip after '+' → 'apple' → 'Apple'
      expect(
        fakeUserRepository.createCalls.single.displayName,
        equals('Apple'),
      );
    });

    test('swallows FirebaseException from the repo so the user still '
        'transitions to Authenticated (offline / rules-denial path)', () async {
      fakeUserRepository.nextCreateError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'simulated rules denial',
      );
      fakeAuthService.nextResult = const AuthSuccess(testAuthUser);

      await container
          .read(authProvider.notifier)
          .signInWithEmail(email: 'test@example.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      // Swallowed — call still recorded, state still Authenticated, no rethrow.
      expect(fakeUserRepository.createCalls, hasLength(1));
      expect(container.read(authProvider), isA<Authenticated>());
    });

    test('listener does not call createUserIfNotExists on null emission '
        '(sign-out path)', () async {
      // Seed an authenticated session, drain the resulting create call.
      fakeAuthService.setCurrentUser(testAuthUser);
      await Future<void>.delayed(Duration.zero);
      fakeUserRepository.createCalls.clear();

      // Now emit null (sign-out).
      fakeAuthService.setCurrentUser(null);
      await Future<void>.delayed(Duration.zero);

      expect(fakeUserRepository.createCalls, isEmpty);
    });

    test('listener invokes the repo on every non-null emission '
        '(idempotency lives in the repo, not the notifier)', () async {
      fakeAuthService.setCurrentUser(testAuthUser);
      await Future<void>.delayed(Duration.zero);
      // Simulate a token refresh: same user re-emitted.
      fakeAuthService.setCurrentUser(testAuthUser);
      await Future<void>.delayed(Duration.zero);

      expect(fakeUserRepository.createCalls.length, equals(2));
    });
  });

  group('signInWithEmail provider suggestion', () {
    test('sets suggestedProvider when password fails and only OAuth providers '
        'exist for the email', () async {
      fakeAuthService.nextResult = const AuthResultFailure(
        'Incorrect email or password.',
      );
      fakeAuthService.nextSignInMethods = const ['apple.com'];

      await container
          .read(authProvider.notifier)
          .signInWithEmail(email: 'shared@example.com', password: 'wrong-pw');

      final state = container.read(authProvider);
      expect(state, isA<AuthError>());
      final failure = (state as AuthError).failure;
      expect(failure.suggestedProvider, equals('apple.com'));
    });

    test('never suggests when fetchSignInMethodsForEmail returns empty '
        '(enumeration protection on / no account)', () async {
      fakeAuthService.nextResult = const AuthResultFailure(
        'Incorrect email or password.',
      );
      fakeAuthService.nextSignInMethods = const [];

      await container
          .read(authProvider.notifier)
          .signInWithEmail(email: 'who@example.com', password: 'wrong-pw');

      final state = container.read(authProvider);
      expect(state, isA<AuthError>());
      expect(
        (state as AuthError).failure.suggestedProvider,
        isNull,
        reason: 'Empty methods list must not leak account existence',
      );
    });

    test('never suggests when password is among the registered methods '
        '(user just typed wrong password)', () async {
      fakeAuthService.nextResult = const AuthResultFailure(
        'Incorrect email or password.',
      );
      fakeAuthService.nextSignInMethods = const ['password', 'apple.com'];

      await container
          .read(authProvider.notifier)
          .signInWithEmail(email: 'mixed@example.com', password: 'wrong-pw');

      expect(
        (container.read(authProvider) as AuthError).failure.suggestedProvider,
        isNull,
        reason: 'Account already has password — user just typed it wrong',
      );
    });
  });
}
