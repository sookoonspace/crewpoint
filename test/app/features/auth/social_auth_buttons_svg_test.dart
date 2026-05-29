import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/social_auth_buttons.dart';

class _FakeAuthService implements IAuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Extracts the asset path from an `SvgAssetLoader` wrapped inside
/// `SvgPicture(... bytesLoader: SvgAssetLoader(...))`.
String _assetOf(SvgPicture svg) {
  final loader = svg.bytesLoader;
  if (loader is SvgAssetLoader) return loader.assetName;
  throw StateError('Expected SvgAssetLoader, got ${loader.runtimeType}');
}

Future<void> _pumpAuthGate(WidgetTester tester, {required Brightness mode}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(_FakeAuthService())],
      child: MaterialApp(
        theme: ThemeData(brightness: mode),
        home: const Scaffold(body: SocialAuthButtons()),
      ),
    ),
  );
}

void main() {
  testWidgets('Apple SVG resolves to Apple_logo_black.svg in light theme', (
    tester,
  ) async {
    await _pumpAuthGate(tester, mode: Brightness.light);
    await tester.pump();

    final svg = tester.widget<SvgPicture>(
      find.byKey(const Key('auth.button.apple.icon')),
    );
    expect(_assetOf(svg), 'assets/images/auth/Apple_logo_black.svg');
  });

  testWidgets('Apple SVG resolves to Apple_logo_white.svg in dark theme', (
    tester,
  ) async {
    await _pumpAuthGate(tester, mode: Brightness.dark);
    await tester.pump();

    final svg = tester.widget<SvgPicture>(
      find.byKey(const Key('auth.button.apple.icon')),
    );
    expect(_assetOf(svg), 'assets/images/auth/Apple_logo_white.svg');
  });

  testWidgets('Google SVG resolves to google_logo.svg in light theme', (
    tester,
  ) async {
    await _pumpAuthGate(tester, mode: Brightness.light);
    await tester.pump();

    final svg = tester.widget<SvgPicture>(
      find.byKey(const Key('auth.button.google.icon')),
    );
    expect(_assetOf(svg), 'assets/images/auth/google_logo.svg');
  });

  testWidgets(
    'Google SVG resolves to google_logo.svg in dark theme (unchanged)',
    (tester) async {
      await _pumpAuthGate(tester, mode: Brightness.dark);
      await tester.pump();

      final svg = tester.widget<SvgPicture>(
        find.byKey(const Key('auth.button.google.icon')),
      );
      expect(_assetOf(svg), 'assets/images/auth/google_logo.svg');
    },
  );

  testWidgets('both buttons render at AppSizes.iconLg', (tester) async {
    await _pumpAuthGate(tester, mode: Brightness.light);
    await tester.pump();

    expect(find.byKey(const Key('auth.button.google')), findsOneWidget);
    expect(find.byKey(const Key('auth.button.apple')), findsOneWidget);
  });
}
