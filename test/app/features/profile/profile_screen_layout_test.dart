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

  group('Sign Out button (extracted from ACCOUNT section)', () {
    testWidgets('ACCOUNT section header is gone', (tester) async {
      await _pumpAt(tester, const Size(375, 812));
      // The ACCOUNT _SectionHeader rendered an all-caps "ACCOUNT" label;
      // sign-out being extracted means that label disappears entirely.
      expect(find.text('ACCOUNT'), findsNothing);
    });

    testWidgets('standalone OutlinedButton labeled "Sign Out" exists exactly '
        'once', (tester) async {
      await _pumpAt(tester, const Size(375, 812));

      final signOutButton = find.byKey(const Key('profile.signOut.button'));
      expect(signOutButton, findsOneWidget);
      expect(
        tester.widget(signOutButton),
        isA<OutlinedButton>(),
        reason:
            'Sign Out is a destructive-action OutlinedButton, not a '
            'ListTile-styled row.',
      );
      // Label is reachable as a Text descendant of the button.
      expect(
        find.descendant(of: signOutButton, matching: find.text('Sign Out')),
        findsOneWidget,
      );
    });

    testWidgets('Sign Out button sits between PAYMENT section and Danger '
        'Zone (visual order)', (tester) async {
      // Pump at a tall viewport so the lazy SliverList materialises every
      // descendant including the Danger Zone below the typical fold.
      await _pumpAt(tester, const Size(800, 2400));
      // Capture vertical center of each anchor widget by finding their
      // RenderBox positions.
      final paymentY = tester.getCenter(find.text('PAYMENT')).dy;
      final signOutY = tester
          .getCenter(find.byKey(const Key('profile.signOut.button')))
          .dy;
      final dangerY = tester.getCenter(find.text('Delete Account')).dy;

      expect(
        signOutY,
        greaterThan(paymentY),
        reason: 'Sign Out must render below the PAYMENT header.',
      );
      expect(
        signOutY,
        lessThan(dangerY),
        reason:
            'Sign Out must render above the Danger Zone delete-account '
            'tile.',
      );
    });

    testWidgets('tapping Sign Out surfaces the SignOutSheet confirmation', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(800, 2400));
      // Sheet not visible before tap.
      expect(find.text('Sign out of CrewPoint?'), findsNothing);

      await tester.tap(find.byKey(const Key('profile.signOut.button')));
      // Drive the modal-show animation manually — Lottie's animation
      // controller would block `pumpAndSettle` indefinitely.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The bottom sheet renders its distinctive title.
      expect(find.text('Sign out of CrewPoint?'), findsOneWidget);
    });
  });
}
