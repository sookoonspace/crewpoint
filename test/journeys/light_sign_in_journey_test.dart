import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/i18n/script_fonts.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/core/services/incoming_links.dart';
import 'package:crewpoint_app/app/features/auth/presentation/email_link_screen.dart';

import '../harness/fake_incoming_links.dart';
import '../harness/sign_in_harness.dart';

/// #241 (Spec #233 Req 9, 12): light sign-in for registering, by email
/// link, phone code, Google or Apple, with no password and no onboarding on
/// the way, and the email link opened on this device, another device, or
/// too late.
void main() {
  const slug = SignInHarness.slug;
  const register = '/e/$slug/register';
  const pendingKey = 'pending_sign_in_email_v1';

  /// A sign-in link as Firebase's handler hands it to `/auth/link`.
  String link(String code, {String to = register}) =>
      '/auth/link?to=${Uri.encodeComponent(to)}&apiKey=k&oobCode=$code'
      '&mode=signIn&lang=en';

  group('Register asks for sign-in only when needed', () {
    testWidgets('signed out, Register offers an email link, a phone code, '
        'Google and Apple', (tester) async {
      final h = SignInHarness();
      await h.pump(tester, register);
      expect(h.location, register);
      expect(find.text('Sign in to carry on'), findsOneWidget);
      for (final key in [
        'auth.light.email',
        'auth.light.sendLink',
        'auth.light.phone',
        'auth.light.sendCode',
        'auth.button.google',
        'auth.button.apple',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      await h.finish(tester);
    });

    testWidgets('the email link is sent in our words, back to the form', (
      tester,
    ) async {
      final h = SignInHarness();
      await h.pump(tester, register);
      await h.type(tester, const Key('auth.light.email'), 'not-an-email');
      await h.tap(tester, const Key('auth.light.sendLink'));
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await h.type(tester, const Key('auth.light.email'), ' Asha@Example.com');
      await h.tap(tester, const Key('auth.light.sendLink'));
      expect(h.auth.signInLinksSent, ['asha@example.com|$register|en']);
      expect(find.text('Check your email'), findsOneWidget);
      // Kept on this device, so opening the link here signs in at once.
      expect(h.prefs.getString(pendingKey), 'asha@example.com');
      await h.finish(tester);
    });

    testWidgets('too many links: "Please try again in a few minutes"', (
      tester,
    ) async {
      final h = SignInHarness();
      h.auth.sendSignInLinkError = FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'Please try again in a few minutes.',
      );
      await h.pump(tester, register);
      await h.type(tester, const Key('auth.light.email'), 'asha@example.com');
      await h.tap(tester, const Key('auth.light.sendLink'));
      expect(find.text('Please try again in a few minutes'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('a phone code signs in and carries on to the form, with no '
        'onboarding', (tester) async {
      final h = SignInHarness(onboarded: false);
      await h.pump(tester, register);
      // Read in the event's country, from its time zone.
      await h.type(tester, const Key('auth.light.phone'), '(312) 555-0142');
      await h.tap(tester, const Key('auth.light.sendCode'));
      expect(h.auth.phoneCodesSent, ['+13125550142']);
      expect(find.text('We texted a code to +13125550142.'), findsOneWidget);
      await h.type(tester, const Key('auth.light.code'), '000000');
      await h.tap(tester, const Key('auth.light.confirmCode'));
      expect(
        find.text("That code isn't right. Check it and try again."),
        findsOneWidget,
      );
      await h.type(tester, const Key('auth.light.code'), '123456');
      await h.tap(tester, const Key('auth.light.confirmCode'));
      expect(h.location, register);
      expect(find.byKey(const Key('registration.form.progress')), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('codes go only to US, Canadian and UK numbers', (tester) async {
      final h = SignInHarness();
      await h.pump(tester, register);
      await h.type(tester, const Key('auth.light.phone'), '+91 98765 43210');
      await h.tap(tester, const Key('auth.light.sendCode'));
      expect(
        find.text('Codes can be sent only to US, Canadian and UK numbers.'),
        findsOneWidget,
      );
      expect(h.auth.phoneCodesSent, isEmpty);
      await h.type(tester, const Key('auth.light.phone'), '+44 7700 900123');
      await h.tap(tester, const Key('auth.light.sendCode'));
      expect(h.auth.phoneCodesSent, ['+447700900123']);
      await h.finish(tester);
    });

    testWidgets('signed in, Register goes straight to the form', (
      tester,
    ) async {
      final h = SignInHarness(
        signedInAs: const AuthUser(uid: 'asha', email: 'asha@example.com'),
      );
      await h.pump(tester, register);
      expect(find.byKey(const Key('registration.form.progress')), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('an invited event needs no account: its groups use their '
        'personal links', (tester) async {
      final h = SignInHarness();
      await h.pump(tester, '/e/shah-wedding/register');
      expect(
        find.byKey(const Key('registration.gate.invitedOnly')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('auth.light.email')), findsNothing);
      await h.finish(tester);
    });
  });

  group('the email link', () {
    testWidgets('on the device that asked, it signs in at once and returns '
        'to the form', (tester) async {
      final h = SignInHarness(onboarded: false);
      h.auth.linkEmails['ok1'] = 'asha@example.com';
      await h.pump(
        tester,
        link('ok1'),
        stored: {pendingKey: 'asha@example.com'},
      );
      expect(h.location, register);
      expect(h.auth.currentUser?.email, 'asha@example.com');
      expect(h.prefs.getString(pendingKey), isNull);
      expect(find.byKey(const Key('registration.form.progress')), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('opened in the app through /__/auth/links, it signs in and '
        'returns to the form', (tester) async {
      final h = SignInHarness(onboarded: false);
      h.auth.linkEmails['ok3'] = 'asha@example.com';
      const action =
          'https://crewpoint-dev.web.app/__/auth/action?apiKey=k&mode=signIn'
          '&oobCode=ok3&continueUrl=https%3A%2F%2Fcrewpoint-dev.web.app'
          '%2Fauth%2Flink%3Fto%3D%252Fe%252Fconvention-2027%252Fregister';
      final route = routeForLink(
        Uri.parse(
          'https://crewpoint-dev.web.app/__/auth/links?link='
          '${Uri.encodeComponent(action)}',
        ),
      )!;
      await h.pump(tester, route, stored: {pendingKey: 'asha@example.com'});
      expect(h.location, register);
      expect(h.auth.currentUser?.email, 'asha@example.com');
      await h.finish(tester);
    });

    testWidgets('on another device: "Confirm your email to finish signing '
        'in", refusing a different address', (tester) async {
      final h = SignInHarness();
      h.auth.linkEmails['ok2'] = 'asha@example.com';
      await h.pump(tester, link('ok2'));
      expect(
        find.text('Confirm your email to finish signing in'),
        findsOneWidget,
      );
      await h.type(tester, const Key('auth.link.email'), 'ravi@example.com');
      await h.tap(tester, const Key('auth.link.continue'));
      expect(
        find.text('This link was sent to a different email'),
        findsOneWidget,
      );
      expect(h.auth.currentUser, isNull);
      await h.type(tester, const Key('auth.link.email'), 'Asha@example.com');
      await h.tap(tester, const Key('auth.link.continue'));
      expect(h.location, register);
      await h.finish(tester);
    });

    testWidgets('expired or used: says so, with Send a new link, a phone '
        'code and Google or Apple on the same screen', (tester) async {
      final h = SignInHarness();
      await h.pump(
        tester,
        link('gone'),
        stored: {pendingKey: 'asha@example.com'},
      );
      expect(
        find.text('This sign-in link has expired or was already used'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('auth.light.phone')), findsOneWidget);
      expect(find.byKey(const Key('auth.button.google')), findsOneWidget);
      expect(find.text('Send a new link'), findsOneWidget);
      await h.tap(tester, const Key('auth.light.sendLink'));
      expect(h.auth.signInLinksSent, ['asha@example.com|$register|en']);
      await h.finish(tester);
    });

    testWidgets('something that is not a sign-in link reads as expired', (
      tester,
    ) async {
      final h = SignInHarness();
      await h.pump(tester, '/auth/link?to=%2Fe%2Fx');
      expect(find.byKey(const Key('auth.link.expired')), findsOneWidget);
      await h.finish(tester);
    });

    test('returns only to invite links, event pages and personal links', () {
      expect(safeReturnPath('/e/x/register'), '/e/x/register');
      expect(safeReturnPath('/join/ABC234'), '/join/ABC234');
      for (final bad in ['/profile', 'https://evil.example', '//evil', null]) {
        expect(safeReturnPath(bad), '/', reason: '$bad');
      }
    });
  });

  group('IIncomingLinkSource (App Links and Universal Links)', () {
    test('opens the links the app handles, on any of its paths', () async {
      final source = FakeIncomingLinkSource();
      final opened = <String>[];
      final sub = followIncomingLinks(source, opened.add);
      final host = AppFlavor.current.legalBaseUrl;
      source
        ..open('$host/e/convention-2027')
        ..open('$host/join/ABC234')
        ..open('$host/auth/link?to=%2Fr%2Fabc&oobCode=x&mode=signIn')
        ..open('$host/profile')
        ..open('$host/legal/privacy.html');
      await Future<void>.delayed(Duration.zero);
      expect(opened, [
        '/e/convention-2027',
        '/join/ABC234',
        '/auth/link?to=%2Fr%2Fabc&oobCode=x&mode=signIn',
      ]);
      await sub.cancel();
      await source.close();
    });

    test("Firebase's /__/auth/links becomes /auth/link, keeping the whole "
        'link and where to return', () {
      const action =
          'https://crewpoint-dev.web.app/__/auth/action?apiKey=k&mode=signIn'
          '&oobCode=abc&continueUrl=https%3A%2F%2Fcrewpoint-dev.web.app'
          '%2Fauth%2Flink%3Fto%3D%252Fe%252Fconvention-2027%252Fregister';
      final route = Uri.parse(
        routeForLink(
          Uri.parse(
            'https://crewpoint-dev.web.app/__/auth/links?link='
            '${Uri.encodeComponent(action)}',
          ),
        )!,
      );
      expect(route.path, '/auth/link');
      expect(route.queryParameters['to'], '/e/convention-2027/register');
      expect(route.queryParameters['link'], action);
      expect(routeForLink(Uri.parse('https://x/__/auth/links')), isNull);
    });

    test('routeForLink ignores paths the app does not handle', () {
      expect(routeForLink(Uri.parse('https://x/r/tok')), '/r/tok');
      expect(routeForLink(Uri.parse('https://x/')), isNull);
      expect(routeForLink(Uri.parse('https://x/auth/linked')), isNull);
    });
  });

  group('router (Req 9)', () {
    for (final (name, onboarded, signedIn) in [
      ('signed out', true, false),
      ('new', false, false),
      ('signed in', true, true),
    ]) {
      testWidgets('a $name visitor opens /e/:eventSlug/registration with no '
          'onboarding', (tester) async {
        final h = SignInHarness(
          onboarded: onboarded,
          signedInAs: signedIn
              ? const AuthUser(uid: 'asha', email: 'asha@example.com')
              : null,
        );
        await h.pump(tester, '/e/$slug/registration');
        expect(h.location, '/e/$slug/registration');
        expect(
          find.byKey(
            Key(signedIn ? 'registration.mine.none' : 'auth.light.email'),
          ),
          findsOneWidget,
        );
        await h.finish(tester);
      });
    }

    testWidgets('someone who signed in only to register sees onboarding the '
        'next time they open the app normally', (tester) async {
      final h = SignInHarness(
        onboarded: false,
        signedInAs: const AuthUser(uid: 'asha', email: 'asha@example.com'),
      );
      await h.pump(tester, register);
      expect(find.byKey(const Key('registration.form.progress')), findsOneWidget);
      h.router.go('/dashboard');
      await h.settle(tester);
      expect(h.location, startsWith('/onboarding'));
      await h.finish(tester);
    });
  });

  testWidgets('Req 71 fits a 320 px phone at 200% text, in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final h = SignInHarness();
    await h.pump(tester, register, dark: true);
    expect(tester.takeException(), isNull);
    for (final key in [
      'auth.light.sendLink',
      'auth.light.sendCode',
      'auth.button.google',
    ]) {
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    await h.finish(tester);
  });

  testWidgets('Req 71 the expired-link screen in Gujarati fits 320 px at '
      '200% text', (tester) async {
    await tester.runAsync(
      () =>
          const AssetFontLoader().load('NotoSansGujarati', gujaratiFontAssets),
    );
    tester.view.physicalSize = const Size(320, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final h = SignInHarness();
    await h.pump(
      tester,
      link('gone'),
      stored: {pendingKey: 'asha@example.com'},
      locale: const Locale('gu'),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('નવી લિંક મોકલો'), findsOneWidget);
    await h.finish(tester);
  });
}
