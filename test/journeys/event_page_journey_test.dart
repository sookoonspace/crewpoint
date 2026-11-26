import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/i18n/script_fonts.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/registration/application/event_page_provider.dart';
import 'package:crewpoint_app/app/features/registration/domain/public_event.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';
import 'package:crewpoint_app/l10n/gen/app_localizations.dart';

import '../app/features/auth/fake_auth_service.dart';
import '../harness/fake_member_calls.dart';
import '../harness/fake_qr.dart';

class _Launcher implements IUrlLauncher {
  final launched = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return true;
  }
}

/// #240 (Spec #233 Req 9-11, 13a, 14): the public event page at
/// `/e/:eventSlug`, for a visitor who is not signed in. The server's side is
/// in `functions/test/registration/eventPage.test.ts`.
void main() {
  late FakeMemberCalls calls;
  late FakeQrRenderer qr;
  late _Launcher launcher;
  const slug = 'convention-2027';
  final link = '${AppFlavor.current.legalBaseUrl}/e/$slug';

  final convention = PublicEvent(
    state: PublicEventState.open,
    slug: slug,
    title: 'Convention 2027',
    description: 'Three days together in Chicago.',
    startDate: DateTime.utc(2027, 7, 16),
    endDate: DateTime.utc(2027, 7, 18),
    dateOnly: true,
    timeZone: 'America/Chicago',
    venues: const [
      PublicVenue(
        name: 'Hall A',
        address: '1 Main St, Chicago',
        mapUrl: 'https://maps.example/hall-a',
      ),
      PublicVenue(name: 'Park'),
    ],
    included: const LocalText('Lunch, dinner and a T-shirt'),
    deadline: DateTime.utc(2027, 6, 30, 4, 59),
    mode: RegistrationMode.open,
    labels: const {
      'registration': {'one': 'Registration', 'other': 'Registrations'},
      'group': {'one': 'Family', 'other': 'Families'},
    },
  );

  Future<void> open(
    WidgetTester tester, {
    PublicEvent? page,
    Object? failFirst,
    Size size = const Size(375, 2400),
    Locale? locale,
    bool dark = false,
    Map<String, dynamic>? embedded,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    calls = FakeMemberCalls();
    if (page != null) calls.eventPages[slug] = page;
    calls.failNext = failFirst;
    qr = FakeQrRenderer();
    launcher = _Launcher();
    final router = createRouter(
      isOnboardingComplete: () => false,
      isAuthenticated: () => false,
      initialLocation: '/e/Convention-2027',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              authRepository: AuthRepository(authService: FakeAuthService()),
            ),
          ),
          memberCallsProvider.overrideWithValue(calls),
          qrRendererProvider.overrideWithValue(qr),
          urlLauncherProvider.overrideWithValue(launcher),
          // What the server put in the first page, if anything.
          embeddedEventSourceProvider.overrideWithValue(
            (s) => embedded != null && embedded['slug'] == s ? embedded : null,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: CpTheme.light(),
          darkTheme: CpTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: locale,
          localizationsDelegates: locale == null
              ? null
              : AppLocalizations.localizationsDelegates,
          supportedLocales: locale == null
              ? const [Locale('en', 'US')]
              : AppLocalizations.supportedLocales,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Req 10 a visitor who is not signed in sees the public fields, '
      'places remaining, the QR code and Register', (tester) async {
    await open(tester, page: convention);
    // Found by its slug, whatever its case, with no sign-in or onboarding.
    expect(calls.calls, ['getEventPage:convention-2027']);
    expect(find.text('Convention 2027'), findsOneWidget);
    expect(find.text('Fri, Jul 16, 2027 – Sun, Jul 18, 2027'), findsOneWidget);
    expect(find.text('Hall A'), findsOneWidget);
    expect(find.text('Address to be announced'), findsOneWidget);
    expect(find.text('Three days together in Chicago.'), findsOneWidget);
    expect(find.text('Lunch, dinner and a T-shirt'), findsOneWidget);
    expect(find.text('Places remain'), findsOneWidget);
    expect(
      find.textContaining('Registration closes Tue, Jun 29, 2027'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('events.page.register')), findsOneWidget);
    expect(qr.rendered.last, link);
    expect(find.text(link), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Req 69 the details the server put in the first page show at '
      'once, with no call that waits on App Check', (tester) async {
    await open(
      tester,
      embedded: {
        'state': 'open',
        'slug': slug,
        'title': 'Convention 2027',
        'description': 'Three days together in Chicago.',
        'startDate': DateTime.utc(2027, 7, 16).millisecondsSinceEpoch,
        'endDate': DateTime.utc(2027, 7, 18).millisecondsSinceEpoch,
        'dateOnly': true,
        'timeZone': 'America/Chicago',
        'venues': <Object>[],
        'included': null,
        'deadline': DateTime.utc(2027, 6, 30, 4, 59).millisecondsSinceEpoch,
        'mode': 'open',
        'placesRemain': true,
        'hasCover': false,
        'labels': <String, Object>{},
      },
    );
    expect(calls.calls, isEmpty);
    expect(find.text('Convention 2027'), findsOneWidget);
    expect(find.text('Fri, Jul 16, 2027 – Sun, Jul 18, 2027'), findsOneWidget);
    expect(find.byKey(const Key('events.page.register')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('details for another event in the first page are ignored', (
    tester,
  ) async {
    await open(
      tester,
      page: convention,
      embedded: {'state': 'open', 'slug': 'other-event', 'title': 'Other'},
    );
    expect(calls.calls, ['getEventPage:convention-2027']);
    expect(find.text('Other'), findsNothing);
    await finish(tester);
  });

  testWidgets('a venue opens its map', (tester) async {
    await open(tester, page: convention);
    await tap(tester, const Key('events.page.venue.0'));
    expect(launcher.launched.single.toString(), 'https://maps.example/hall-a');
    await finish(tester);
  });

  testWidgets('Register asks a signed-out visitor to sign in, and Back '
      'returns to the event (#241)', (tester) async {
    await open(tester, page: convention);
    await tap(tester, const Key('events.page.register'));
    expect(find.byKey(const Key('registration.gate.signIn')), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('events.page.title')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a full event says you will join the waitlist, with no number', (
    tester,
  ) async {
    await open(
      tester,
      page: const PublicEvent(
        state: PublicEventState.open,
        slug: slug,
        title: 'Convention 2027',
        mode: RegistrationMode.open,
        placesRemain: false,
      ),
    );
    expect(find.text("Full: you'll join the waitlist"), findsOneWidget);
    expect(find.byKey(const Key('events.page.register')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Req 14 a draft shows "Not open yet" and nothing else', (
    tester,
  ) async {
    await open(
      tester,
      page: const PublicEvent(state: PublicEventState.notOpen),
    );
    expect(find.text('Not open yet'), findsOneWidget);
    expect(find.byKey(const Key('events.page.title')), findsNothing);
    expect(find.byKey(const Key('events.page.register')), findsNothing);
    await finish(tester);
  });

  testWidgets('Req 14 an ended event shows registration has closed, with no '
      'Register', (tester) async {
    await open(
      tester,
      page: const PublicEvent(
        state: PublicEventState.closed,
        slug: slug,
        title: 'Convention 2027',
        mode: RegistrationMode.open,
      ),
    );
    expect(find.text('Registration is closed'), findsOneWidget);
    expect(find.byKey(const Key('events.page.register')), findsNothing);
    await finish(tester);
  });

  testWidgets('an invited event points to the personal link instead', (
    tester,
  ) async {
    await open(
      tester,
      page: const PublicEvent(
        state: PublicEventState.open,
        slug: slug,
        title: 'Shah wedding',
        labels: {
          'group': {'one': 'Guest party', 'other': 'Guest parties'},
        },
      ),
    );
    expect(find.byKey(const Key('events.page.register')), findsNothing);
    expect(
      find.text(
        'Registration is by invitation. Use the personal link your guest '
        'party was sent.',
      ),
      findsOneWidget,
    );
    await finish(tester);
  });

  testWidgets('Req 13a too many opens: "Please try again in a few minutes"', (
    tester,
  ) async {
    await open(
      tester,
      page: convention,
      failFirst: FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'Please try again in a few minutes.',
        details: const {'reason': 'rateLimited'},
      ),
    );
    expect(find.text('Please try again in a few minutes'), findsOneWidget);
    await tap(tester, const Key('events.page.retry'));
    expect(find.text('Convention 2027'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an unknown link says the event cannot be found', (tester) async {
    await open(tester);
    expect(find.text("We couldn't find this event"), findsOneWidget);
    await finish(tester);
  });

  testWidgets('offline, it says so and retries', (tester) async {
    await open(
      tester,
      page: convention,
      failFirst: FirebaseFunctionsException(
        code: 'unavailable',
        message: 'offline',
      ),
    );
    expect(find.text("Couldn't load the event"), findsOneWidget);
    await tap(tester, const Key('events.page.retry'));
    expect(find.text('Convention 2027'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Req 71 fits a 320 px phone at 200% text, in dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await open(
      tester,
      page: convention,
      size: const Size(320, 6000),
      dark: true,
    );
    expect(tester.takeException(), isNull);
    for (final key in [
      'events.page.register',
      'events.page.copy',
      'events.page.share',
      'events.page.venue.0',
      'events.page.language.en',
    ]) {
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    await finish(tester);
  });

  testWidgets('Req 71 in Gujarati, it fits a 320 px phone at 200% text', (
    tester,
  ) async {
    await tester.runAsync(
      () =>
          const AssetFontLoader().load('NotoSansGujarati', gujaratiFontAssets),
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await open(
      tester,
      page: convention,
      size: const Size(320, 6000),
      locale: const Locale('gu'),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('જગ્યા બાકી છે'), findsOneWidget);
    await finish(tester);
  });
}
