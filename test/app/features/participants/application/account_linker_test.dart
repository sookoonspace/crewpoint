import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/data/member_calls.dart';
import 'package:crewpoint_app/app/features/participants/application/account_linker.dart';

import '../../../../harness/fake_member_calls.dart';

/// Req 46 (X-05, L-01, L-02): once someone is signed in with a verified
/// email, the app asks the server to link them to their own participant
/// records, once per account per session. An unverified email waits until
/// the person verifies it. The server decides what links.
class _Auth extends AuthNotifier {
  _Auth(this.initial) : super(authRepository: _Unused());
  final AuthState initial;

  @override
  AuthState build() => initial;

  void set(AuthState next) => state = next;
}

class _Unused implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AppUser _user(
  String uid, {
  bool verified = true,
  List<String> providers = const ['password'],
}) => AppUser(
  uid: uid,
  email: '$uid@x.test',
  emailVerified: verified,
  providerIds: providers,
);

void main() {
  late FakeMemberCalls calls;
  late ProviderContainer container;
  late _Auth auth;

  ProviderContainer start(AuthState initial, {LinkResult? result}) {
    calls = FakeMemberCalls();
    if (result != null) calls.linkResult = result;
    auth = _Auth(initial);
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => auth),
        memberCallsProvider.overrideWithValue(calls),
      ],
    );
    addTearDown(container.dispose);
    container.listen(accountLinkerProvider, (_, _) {});
    return container;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'L-01 signing in with Google links the account to its registration',
    () async {
      start(Authenticated(_user('ravi', providers: const ['google.com'])));
      await settle();
      expect(calls.calls, ['linkMyParticipants']);
    },
  );

  test(
    'L-02 signing in with Apple links the account after a sign-out',
    () async {
      start(const Unauthenticated());
      await settle();
      expect(calls.calls, isEmpty);
      auth.set(Authenticated(_user('ravi', providers: const ['apple.com'])));
      await settle();
      expect(calls.calls, ['linkMyParticipants']);
    },
  );

  test('an unverified email waits until it is verified', () async {
    start(Authenticated(_user('ravi', verified: false)));
    await settle();
    expect(calls.calls, isEmpty);
    auth.set(Authenticated(_user('ravi')));
    await settle();
    expect(calls.calls, ['linkMyParticipants']);
  });

  test('once per account per session, and again for another account', () async {
    start(Authenticated(_user('ravi')));
    await settle();
    auth.set(Authenticated(_user('ravi')));
    await settle();
    expect(calls.calls, hasLength(1));
    auth.set(Authenticated(_user('mira')));
    await settle();
    expect(calls.calls, hasLength(2));
  });

  test('the result is kept, so the shell can say what was linked', () async {
    start(
      Authenticated(_user('ravi')),
      result: (
        linked: const ['conv'],
        asked: const <String>[],
        unverified: false,
      ),
    );
    await settle();
    expect(container.read(accountLinkerProvider)?.linked, ['conv']);
  });

  test('a failure is tried again the next time the account signs in', () async {
    start(const Unauthenticated());
    calls.failNext = Exception('offline');
    auth.set(Authenticated(_user('ravi')));
    await settle();
    expect(container.read(accountLinkerProvider), isNull);
    auth.set(const Unauthenticated());
    auth.set(Authenticated(_user('ravi')));
    await settle();
    expect(calls.calls, hasLength(2));
  });
}
