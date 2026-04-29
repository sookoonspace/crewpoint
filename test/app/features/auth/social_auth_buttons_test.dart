import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/social_auth_buttons.dart';

class _FakeAuthService implements IAuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('renders Apple + Google tiles unconditionally', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(_FakeAuthService())],
        child: const MaterialApp(home: Scaffold(body: SocialAuthButtons())),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });

  testWidgets('Apple tile invokes authProvider.signInWithApple on tap', (
    tester,
  ) async {
    var appleTaps = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => _CountingAuthNotifier(onAppleTap: () => appleTaps++),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SocialAuthButtons())),
      ),
    );

    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();

    expect(appleTaps, equals(1));
  });
}

class _CountingAuthNotifier extends AuthNotifier {
  _CountingAuthNotifier({required this.onAppleTap})
    : super(authRepository: _UnusedAuthRepository());

  final VoidCallback onAppleTap;

  @override
  AuthState build() => const Unauthenticated();

  @override
  Future<void> signInWithApple() async {
    onAppleTap();
  }
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Auth repository not used in this test');
}
