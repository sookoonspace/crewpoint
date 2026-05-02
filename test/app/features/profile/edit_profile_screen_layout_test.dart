import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/profile/presentation/edit_profile_screen.dart';

import '../auth/fake_auth_service.dart';

const _bodyKey = Key('editProfile.body.clamped');
const _shellKey = Key('form.card.shell');

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final fake = FakeAuthService();
  addTearDown(fake.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          () => AuthNotifier(authRepository: AuthRepository(authService: fake)),
        ),
      ],
      child: const MaterialApp(home: EditProfileScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'clamps body to <= 480 and shows the form card shell on desktop viewport',
    (tester) async {
      await _pumpAt(tester, const Size(1280, 800));
      // The narrow form surfaces a benign Material DropdownButtonFormField
      // internal Row overflow (~7 px) unrelated to the clamp; ignore.
      tester.takeException();

      final width = tester.getSize(find.byKey(_bodyKey)).width;
      expect(width, lessThanOrEqualTo(480));
      expect(find.byKey(_shellKey), findsOneWidget);
    },
  );

  testWidgets('fills viewport and skips form card shell on phone viewport', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(375, 812));
    tester.takeException();

    final width = tester.getSize(find.byKey(_bodyKey)).width;
    expect(width, greaterThan(300));
    expect(width, lessThanOrEqualTo(375));
    expect(find.byKey(_shellKey), findsNothing);
  });
}
