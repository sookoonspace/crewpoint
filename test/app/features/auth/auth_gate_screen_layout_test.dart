import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart' show authProvider;
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/presentation/auth_gate_screen.dart';

import 'fake_auth_service.dart';

const _columnKey = Key('auth.gate.column');

Future<void> _pumpAuthGate(
  WidgetTester tester, {
  required FakeAuthService fake,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          () => AuthNotifier(authRepository: AuthRepository(authService: fake)),
        ),
      ],
      child: const MaterialApp(home: AuthGateScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeAuthService fake;

  setUp(() {
    fake = FakeAuthService();
  });

  tearDown(() {
    fake.dispose();
  });

  testWidgets(
    'auth-gate column clamps to <= 480 px on a desktop-width viewport',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await _pumpAuthGate(tester, fake: fake);

      final size = tester.getSize(find.byKey(_columnKey));
      expect(
        size.width,
        lessThanOrEqualTo(480),
        reason:
            'Wide viewports should not stretch buttons + text fields '
            'edge-to-edge; the auth gate must clamp at a readable column.',
      );
    },
  );

  testWidgets('auth-gate column fills the viewport on a phone-width device', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));

    await _pumpAuthGate(tester, fake: fake);

    // After the surrounding SafeArea + 24-px outer padding the inner
    // column fills the remaining width. We just need to confirm the
    // 480-px clamp doesn't kick in below the breakpoint.
    final size = tester.getSize(find.byKey(_columnKey));
    expect(size.width, greaterThan(300));
    expect(size.width, lessThan(375));
  });
}
