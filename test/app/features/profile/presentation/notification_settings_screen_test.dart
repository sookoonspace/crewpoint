import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/fcm_gateway.dart';
import 'package:crewpoint_app/app/core/services/fcm_service.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';
import 'package:crewpoint_app/app/features/profile/presentation/notification_settings_screen.dart';

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
  }) async {}

  @override
  Future<void> removeFcmToken({
    required String uid,
    required String token,
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
  Future<String?> getToken() async => 'fcm';
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
}

Future<void> _pumpScreen(WidgetTester tester, _InMemoryUserRepo repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(repo),
        fcmGatewayProvider.overrideWithValue(_NoopFcmGateway()),
        fcmServiceProvider.overrideWith((ref) {
          return FcmService(gateway: _NoopFcmGateway(), userRepository: repo);
        }),
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
      // master + 4 categories + criticalOptIn opt-in.
      expect(tiles.length, 6);
      // All defaults TRUE except the criticalOptIn opt-in (Phase 4).
      expect(tiles.take(5).every((t) => t.value == true), isTrue);
      expect(tiles[5].value, isFalse);
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
      // eventUpdates, criticalOptIn].
      expect(tiles[1].onChanged, isNull);
      expect(tiles[2].onChanged, isNull);
      expect(tiles[3].onChanged, isNull);
      expect(tiles[4].onChanged, isNull);
      expect(tiles[5].onChanged, isNull);
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
      'criticalOptIn tile defaults to OFF (Apple/Google opt-in only)',
      (tester) async {
        final repo = _InMemoryUserRepo();
        await _pumpScreen(tester, repo);

        final tile = tester.widget<SwitchListTile>(
          find.descendant(
            of: find.byKey(const Key('notifSettings.criticalOptIn.tile')),
            matching: find.byType(SwitchListTile),
          ),
        );
        expect(tile.value, isFalse);
      },
    );

    testWidgets(
      'toggling criticalOptIn ON persists criticalOptIn=true AND shows re-confirmation snackbar',
      (tester) async {
        final repo = _InMemoryUserRepo();
        await _pumpScreen(tester, repo);

        await tester.tap(
          find.byKey(const Key('notifSettings.criticalOptIn.tile')),
        );
        await tester.pumpAndSettle();

        expect(repo.updates, isNotEmpty);
        expect(repo.updates.last.criticalOptIn, isTrue);
        // Confirmation toast acknowledges the elevated permission.
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets('criticalOptIn tile is disabled when urgentChat is OFF', (
      tester,
    ) async {
      final repo = _InMemoryUserRepo()
        ..prefs = const NotificationPrefs(urgentChat: false);
      await _pumpScreen(tester, repo);

      final tile = tester.widget<SwitchListTile>(
        find.descendant(
          of: find.byKey(const Key('notifSettings.criticalOptIn.tile')),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(tile.onChanged, isNull);
    });
  });
}
