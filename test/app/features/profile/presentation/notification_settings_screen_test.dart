import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/device_timezone.dart';
import 'package:crewpoint_app/app/core/services/fcm_gateway.dart';
import 'package:crewpoint_app/app/core/services/fcm_service.dart';
import 'package:crewpoint_app/app/core/services/notification_channels.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';
import 'package:crewpoint_app/app/features/profile/presentation/notification_settings_screen.dart';

class _FakeChannels implements INotificationChannels {
  @override
  Future<void> registerAll() async {}
}

class _FakeDeviceTimezone implements IDeviceTimezone {
  _FakeDeviceTimezone(this.iana);

  final String iana;

  @override
  Future<String> getLocalTimezone() async => iana;
}

class _InMemoryUserRepo implements IUserRepository {
  NotificationPrefs prefs = const NotificationPrefs();
  final List<NotificationPrefs> updates = [];

  @override
  Future<NotificationPrefs> getNotificationPrefs(String uid) async => prefs;

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required NotificationPrefs prefs,
  }) async {
    this.prefs = prefs;
    updates.add(prefs);
  }

  @override
  Future<AppUser?> getUser(String uid) async => null;

  @override
  Future<void> saveProfile({
    required String uid,
    required String displayName,
    String? photoUrl,
    String? paymentMethod,
    String? paymentHandle,
    String? venmoHandle,
    String? cashappHandle,
  }) async {}

  @override
  Future<void> createUserIfNotExists({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    List<String> providerIds = const [],
  }) async {}

  @override
  Future<void> addFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {}

  @override
  Future<void> removeFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {}
}

class _NoopFcmGateway implements IFcmGateway {
  @override
  Future<String?> getApnsToken() async => 'apns';
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> triggerApnsRegistration() async {}
  @override
  Future<String?> getToken({String? vapidKey}) async => 'fcm';
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _InMemoryUserRepo repo, {
  _FakeChannels? channels,
  IDeviceTimezone? deviceTimezone,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(repo),
        fcmGatewayProvider.overrideWithValue(_NoopFcmGateway()),
        fcmServiceProvider.overrideWith((ref) {
          return FcmService(gateway: _NoopFcmGateway(), userRepository: repo);
        }),
        notificationChannelsProvider.overrideWithValue(
          channels ?? _FakeChannels(),
        ),
        deviceTimezoneProvider.overrideWithValue(
          deviceTimezone ?? _FakeDeviceTimezone('America/New_York'),
        ),
        // Bypass authProvider entirely — the screen only needs the uid.
        currentUserIdProvider.overrideWithValue('u-test'),
      ],
      child: const MaterialApp(home: NotificationSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('NotificationSettingsScreen', () {
    testWidgets('renders master + category tiles with defaults (all ON)', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo();
      await _pumpScreen(tester, repo);

      expect(
        find.byKey(const Key('notifSettings.pushEnabled.tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notifSettings.urgentChat.tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notifSettings.taskUpdates.tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notifSettings.payments.tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notifSettings.eventUpdates.tile')),
        findsOneWidget,
      );

      final tiles = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      // master + 4 categories + quiet-hours toggle + dailyDigest opt-in
      // (Phase 6.1). Phase 4 criticalOptIn tile withdrawn for V1/V2.
      expect(tiles.length, 7);
      // All defaults TRUE except the two opt-ins (quietHours, dailyDigest).
      expect(tiles.take(5).every((t) => t.value == true), isTrue);
      expect(tiles[5].value, isFalse);
      expect(tiles[6].value, isFalse);
    });

    testWidgets('toggling master OFF persists pushEnabled=false', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo();
      await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('notifSettings.pushEnabled.tile')));
      await tester.pumpAndSettle();

      expect(repo.updates, isNotEmpty);
      expect(repo.updates.last.pushEnabled, isFalse);
      expect(repo.prefs.pushEnabled, isFalse);
    });

    testWidgets('category tiles are disabled when master is OFF', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo()
        ..prefs = const NotificationPrefs(pushEnabled: false);
      await _pumpScreen(tester, repo);

      final tiles = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      // Layout order: [master, urgentChat, taskUpdates, payments,
      // eventUpdates, quietHours, dailyDigest]. Every non-master tile
      // should be disabled when master is OFF.
      for (var i = 1; i < tiles.length; i++) {
        expect(
          tiles[i].onChanged,
          isNull,
          reason: 'tile $i should be disabled when master is OFF',
        );
      }
    });

    testWidgets('toggling taskUpdates OFF persists taskUpdates=false', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo();
      await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('notifSettings.taskUpdates.tile')));
      await tester.pumpAndSettle();

      expect(repo.updates, isNotEmpty);
      expect(repo.updates.last.taskUpdates, isFalse);
      // Other flags stay true — copyWith semantics.
      expect(repo.updates.last.pushEnabled, isTrue);
      expect(repo.updates.last.urgentChat, isTrue);
    });

    testWidgets('toggling payments OFF persists payments=false', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo();
      await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('notifSettings.payments.tile')));
      await tester.pumpAndSettle();

      expect(repo.updates, isNotEmpty);
      expect(repo.updates.last.payments, isFalse);
      // Other flags stay true — copyWith semantics.
      expect(repo.updates.last.pushEnabled, isTrue);
      expect(repo.updates.last.urgentChat, isTrue);
      expect(repo.updates.last.taskUpdates, isTrue);
    });

    testWidgets('toggling eventUpdates OFF persists eventUpdates=false', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo();
      await _pumpScreen(tester, repo);

      await tester.tap(
        find.byKey(const Key('notifSettings.eventUpdates.tile')),
      );
      await tester.pumpAndSettle();

      expect(repo.updates, isNotEmpty);
      expect(repo.updates.last.eventUpdates, isFalse);
      // Other flags stay true — copyWith semantics.
      expect(repo.updates.last.pushEnabled, isTrue);
      expect(repo.updates.last.urgentChat, isTrue);
      expect(repo.updates.last.taskUpdates, isTrue);
      expect(repo.updates.last.payments, isTrue);
    });

    testWidgets(
      'critical-alert tile is no longer rendered (Phase 4 withdrawn V1/V2)',
      (tester) async {
        final repo = _InMemoryUserRepo();
        await _pumpScreen(tester, repo);

        expect(
          find.byKey(const Key('notifSettings.criticalOptIn.tile')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('notifSettings.criticalOptIn.dndWarning')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'quietHours tile defaults to OFF when prefs.quietHoursStart is null',
      (tester) async {
        final repo = _InMemoryUserRepo();
        await _pumpScreen(tester, repo);

        final tile = tester.widget<SwitchListTile>(
          find.descendant(
            of: find.byKey(const Key('notifSettings.quietHours.tile')),
            matching: find.byType(SwitchListTile),
          ),
        );
        expect(tile.value, isFalse);
      },
    );

    testWidgets(
      'enabling quietHours persists defaults (22:00-07:00 + IANA timezone from deviceTimezoneProvider)',
      (tester) async {
        final repo = _InMemoryUserRepo();
        await _pumpScreen(
          tester,
          repo,
          deviceTimezone: _FakeDeviceTimezone('Australia/Sydney'),
        );

        final switchTile = find.byKey(
          const Key('notifSettings.quietHours.tile'),
        );
        await tester.ensureVisible(switchTile);
        await tester.pumpAndSettle();
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        expect(repo.updates, isNotEmpty);
        final last = repo.updates.last;
        expect(last.quietHoursStart, 22 * 60);
        expect(last.quietHoursEnd, 7 * 60);
        // The IANA string from the injected provider — *not* the platform
        // default — proves the toggle goes through deviceTimezoneProvider.
        expect(last.timezone, 'Australia/Sydney');
      },
    );

    testWidgets('disabling quietHours clears all three fields to null', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo()
        ..prefs = const NotificationPrefs(
          quietHoursStart: 22 * 60,
          quietHoursEnd: 7 * 60,
          timezone: 'UTC',
        );
      await _pumpScreen(tester, repo);

      final switchTile = find.byKey(const Key('notifSettings.quietHours.tile'));
      await tester.ensureVisible(switchTile);
      await tester.pumpAndSettle();
      await tester.tap(switchTile);
      await tester.pumpAndSettle();

      expect(repo.updates, isNotEmpty);
      final last = repo.updates.last;
      expect(last.quietHoursStart, isNull);
      expect(last.quietHoursEnd, isNull);
      expect(last.timezone, isNull);
    });

    testWidgets(
      'when quietHours enabled, start + end picker rows render the persisted times',
      (tester) async {
        final repo = _InMemoryUserRepo()
          ..prefs = const NotificationPrefs(
            quietHoursStart: 22 * 60,
            quietHoursEnd: 7 * 60,
            timezone: 'America/New_York',
          );
        await _pumpScreen(tester, repo);

        expect(
          find.byKey(const Key('notifSettings.quietHours.start')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('notifSettings.quietHours.end')),
          findsOneWidget,
        );
        // Pickers render the persisted minute-of-day values (zero-padded).
        expect(find.text('22:00'), findsOneWidget);
        expect(find.text('07:00'), findsOneWidget);
      },
    );

    testWidgets('when quietHours OFF, start + end picker rows are absent', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo();
      await _pumpScreen(tester, repo);

      expect(
        find.byKey(const Key('notifSettings.quietHours.start')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('notifSettings.quietHours.end')),
        findsNothing,
      );
    });

    testWidgets('dailyDigest tile defaults to OFF (opt-in only)', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo();
      await _pumpScreen(tester, repo);

      final tile = tester.widget<SwitchListTile>(
        find.descendant(
          of: find.byKey(const Key('notifSettings.dailyDigest.tile')),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(tile.value, isFalse);
    });

    testWidgets('toggling dailyDigest ON persists dailyDigest=true', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo();
      await _pumpScreen(tester, repo);

      final tile = find.byKey(const Key('notifSettings.dailyDigest.tile'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(repo.updates, isNotEmpty);
      expect(repo.updates.last.dailyDigest, isTrue);
    });
  });
}
