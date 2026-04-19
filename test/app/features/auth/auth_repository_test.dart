import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';

import 'fake_auth_service.dart';

void main() {
  late FakeAuthService fakeAuthService;
  late AuthRepository repository;

  const testAuthUser = AuthUser(
    uid: 'uid-123',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  setUp(() {
    fakeAuthService = FakeAuthService();
    repository = AuthRepository(authService: fakeAuthService);
  });

  tearDown(() => fakeAuthService.dispose());

  test('returns typed failure on invalid credentials', () async {
    fakeAuthService.nextResult = const AuthResultFailure(
      'Incorrect email or password.',
    );

    final (:user, :failure) = await repository.signInWithEmail(
      email: 'test@example.com',
      password: 'wrong',
    );

    expect(user, isNull);
    expect(failure, isNotNull);
    expect(failure!.message, contains('Incorrect'));
  });

  test('returns AppUser on successful sign-in', () async {
    fakeAuthService.nextResult = const AuthSuccess(testAuthUser);

    final (:user, :failure) = await repository.signInWithEmail(
      email: 'test@example.com',
      password: 'correct',
    );

    expect(failure, isNull);
    expect(user, isNotNull);
    expect(user!.uid, equals('uid-123'));
    expect(user.email, equals('test@example.com'));
  });
}
