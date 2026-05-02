import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/profile/presentation/profile_screen.dart';

import '../auth/fake_auth_service.dart';

const _bodyKey = Key('profile.body.clamped');

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
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'clamps SliverList subtree to <= 720 while hero stays full-bleed at desktop',
    (tester) async {
      await _pumpAt(tester, const Size(1280, 800));

      final clampedWidth = tester.getSize(find.byKey(_bodyKey)).width;
      expect(clampedWidth, lessThanOrEqualTo(720));

      // Hero spans full viewport width — sits OUTSIDE the sliver clamp.
      final heroFinder = find.text('Profile');
      final heroAncestor = find.ancestor(
        of: heroFinder,
        matching: find.byType(Container),
      );
      final heroWidth = tester.getSize(heroAncestor.first).width;
      expect(heroWidth, equals(1280));
    },
  );

  testWidgets('body fills viewport on phone width', (tester) async {
    await _pumpAt(tester, const Size(375, 812));

    final clampedWidth = tester.getSize(find.byKey(_bodyKey)).width;
    expect(clampedWidth, greaterThan(300));
    expect(clampedWidth, lessThanOrEqualTo(375));
  });
}
