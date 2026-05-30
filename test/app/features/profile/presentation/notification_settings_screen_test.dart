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

      final tiles = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(tiles.length, 4);
      expect(tiles.every((t) => t.value == true), isTrue);
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
      // Layout order: [master, urgentChat, taskUpdates, payments].
      expect(tiles[1].onChanged, isNull);
      expect(tiles[2].onChanged, isNull);
      expect(tiles[3].onChanged, isNull);
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
  });
}
