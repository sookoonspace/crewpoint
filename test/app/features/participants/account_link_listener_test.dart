import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/participants/presentation/account_link_listener.dart';

import '../../../harness/fake_member_calls.dart';

/// Req 46: the signed-in shell says when signing in linked someone to their
/// registration, and says nothing otherwise.
class _Auth extends AuthNotifier {
  _Auth() : super(authRepository: _Unused());

  @override
  AuthState build() => const Authenticated(
    AppUser(uid: 'ravi', email: 'ravi@x.test', emailVerified: true),
  );
}

class _Unused implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  Future<FakeMemberCalls> pump(WidgetTester tester, List<String> linked) async {
    final calls = FakeMemberCalls()
      ..linkResult = (
        linked: linked,
        asked: const <String>[],
        unverified: false,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          memberCallsProvider.overrideWithValue(calls),
        ],
        child: const MaterialApp(home: Scaffold(body: AccountLinkListener())),
      ),
    );
    await tester.pump();
    await tester.pump();
    return calls;
  }

  testWidgets('says when an event was linked', (tester) async {
    final calls = await pump(tester, const ['conv']);
    expect(calls.calls, ['linkMyParticipants']);
    expect(
      find.text("You've been linked to your registration in 1 event."),
      findsOneWidget,
    );
  });

  testWidgets('says nothing when nothing was linked', (tester) async {
    await pump(tester, const []);
    expect(find.byKey(const Key('links.linkedToast')), findsNothing);
  });
}
