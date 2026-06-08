import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/fcm_gateway.dart';
import 'package:crewpoint_app/app/core/services/fcm_service.dart';
import 'package:crewpoint_app/app/core/services/notification_channels.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

class _FakeFcmGateway implements IFcmGateway {
  bool permissionGranted = true;
  String? apnsToken = 'apns-1';
  String? currentToken = 'fcm-token-A';
  final _refreshController = StreamController<String>.broadcast();
  bool deleted = false;
  int permissionCalls = 0;
  int getTokenCalls = 0;
  int triggerApnsCalls = 0;

  /// Captures the [vapidKey] passed to the most recent [getToken] call so
  /// tests can assert FcmService threads it through on web.
  String? lastVapidKey;

  @override
  Future<String?> getApnsToken() async => apnsToken;

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permissionGranted;
  }

  @override
  Future<void> triggerApnsRegistration() async {
    triggerApnsCalls++;
  }

  @override
  Future<String?> getToken({String? vapidKey}) async {
    getTokenCalls++;
    lastVapidKey = vapidKey;
    return currentToken;
  }

  @override
  Stream<String> get onTokenRefresh => _refreshController.stream;

  @override
  Future<void> deleteToken() async {
    deleted = true;
    currentToken = null;
  }

  void emitRefresh(String newToken) {
    currentToken = newToken;
    _refreshController.add(newToken);
  }

  Future<void> close() async {
    await _refreshController.close();
  }
}

class _FakeUserRepo implements IUserRepository {
  final List<({String uid, String token, String platform})> added = [];
  final List<({String uid, String token, String platform})> removed = [];

  /// What [getNotificationPrefs] should return for the next call. Tests
  /// mutate this to verify FcmService skips attach when pushEnabled is
  /// false.
  NotificationPrefs prefs = const NotificationPrefs();
  final List<NotificationPrefs> updates = [];

  @override
  Future<void> addFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    added.add((uid: uid, token: token, platform: platform));
  }

  @override
  Future<void> removeFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    removed.add((uid: uid, token: token, platform: platform));
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
  Future<NotificationPrefs> getNotificationPrefs(String uid) async => prefs;

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required NotificationPrefs prefs,
  }) async {
    updates.add(prefs);
    this.prefs = prefs;
  }
}

class _FakeNotificationChannels implements INotificationChannels {
  int registerCalls = 0;

  @override
  Future<void> registerAll() async {
    registerCalls++;
  }
}

void main() {
  late _FakeFcmGateway gateway;
  late _FakeUserRepo repo;
  late _FakeNotificationChannels channels;
  late FcmService service;

  setUp(() {
    gateway = _FakeFcmGateway();
    repo = _FakeUserRepo();
    channels = _FakeNotificationChannels();
    service = FcmService(
      gateway: gateway,
      userRepository: repo,
      notificationChannels: channels,
    );
  });

  tearDown(() async {
    await service.dispose();
    await gateway.close();
  });

  test(
    'attach() requests permission, gets token, writes to user repo',
    () async {
      final ok = await service.attach(uid: 'u1');

      expect(ok, isTrue);
      expect(gateway.permissionCalls, 1);
      expect(gateway.getTokenCalls, 1);
      expect(repo.added, hasLength(1));
      expect(repo.added.first.uid, 'u1');
      expect(repo.added.first.token, 'fcm-token-A');
    },
  );

  test('attach() returns false silently when permission is denied', () async {
    gateway.permissionGranted = false;

    final ok = await service.attach(uid: 'u1');

    expect(ok, isFalse);
    expect(repo.added, isEmpty);
  });

  test('refresh stream upserts the new token under the same uid', () async {
    await service.attach(uid: 'u1');
    expect(repo.added, hasLength(1));

    gateway.emitRefresh('fcm-token-B');
    await Future<void>.delayed(Duration.zero);

    expect(repo.added, hasLength(2));
    expect(repo.added.last.token, 'fcm-token-B');
  });

  test(
    'detach() removes the current token before deleteToken so rules accept the write',
    () async {
      await service.attach(uid: 'u1');
      await service.detach(uid: 'u1');

      expect(repo.removed, hasLength(1));
      expect(repo.removed.first.token, 'fcm-token-A');
      expect(gateway.deleted, isTrue);
    },
  );

  test(
    'attach() short-circuits when notificationPrefs.pushEnabled is false',
    () async {
      repo.prefs = const NotificationPrefs(pushEnabled: false);

      final ok = await service.attach(uid: 'u1');

      expect(ok, isFalse);
      expect(gateway.permissionCalls, 0);
      expect(gateway.getTokenCalls, 0);
      expect(repo.added, isEmpty);
    },
  );

  test(
    'attach() proceeds when pushEnabled true but urgentChat false',
    () async {
      // urgentChat is enforced server-side (in the CF); on the device we
      // still want a token so the user can receive other categories later
      // and so toggling urgentChat back on doesn't require a re-attach.
      repo.prefs = const NotificationPrefs(urgentChat: false);

      final ok = await service.attach(uid: 'u1');

      expect(ok, isTrue);
      expect(repo.added, hasLength(1));
    },
  );

  test(
    'attach() registers notification channels exactly once after permission grant',
    () async {
      final ok = await service.attach(uid: 'u1');

      expect(ok, isTrue);
      expect(channels.registerCalls, 1);
    },
  );

  test(
    'attach() skips channel registration when permission is denied',
    () async {
      gateway.permissionGranted = false;

      final ok = await service.attach(uid: 'u1');

      expect(ok, isFalse);
      expect(channels.registerCalls, 0);
    },
  );

  test(
    'attach() skips channel registration when pushEnabled is false',
    () async {
      repo.prefs = const NotificationPrefs(pushEnabled: false);

      final ok = await service.attach(uid: 'u1');

      expect(ok, isFalse);
      expect(channels.registerCalls, 0);
    },
  );

  test(
    'attach() returns false silently when APNs token is unavailable',
    () async {
      // iOS Simulator path — getApnsToken returns null. We must NOT
      // proceed to getToken(), which would throw `apns-token-not-set`
      // from inside the firebase_messaging plugin.
      gateway.apnsToken = null;

      final ok = await service.attach(uid: 'u1');

      expect(ok, isFalse);
      expect(gateway.getTokenCalls, 0);
      expect(repo.added, isEmpty);
    },
  );

  test('attach() triggers APNs registration after permission grant', () async {
    // firebase_messaging only calls registerForRemoteNotifications once
    // at app launch when status is notDetermined — for auth-gated apps
    // that's wasted because no one has been asked for permission yet.
    // We must re-trigger after the user grants.
    final ok = await service.attach(uid: 'u1');

    expect(ok, isTrue);
    expect(gateway.triggerApnsCalls, 1);
  });

  test(
    'attach() skips APNs registration trigger when permission is denied',
    () async {
      gateway.permissionGranted = false;

      final ok = await service.attach(uid: 'u1');

      expect(ok, isFalse);
      expect(gateway.triggerApnsCalls, 0);
    },
  );

  test(
    'refresh listener writes the token even when initial APNs attach failed',
    () async {
      // First-launch race on iOS: APNs not ready at attach time, but
      // the token arrives ~seconds later via onTokenRefresh. The
      // refresh listener must already be wired so the late token
      // still lands in Firestore.
      gateway.apnsToken = null;

      final ok = await service.attach(uid: 'u1');
      expect(ok, isFalse);
      expect(repo.added, isEmpty);

      // Simulate iOS finishing APNs registration ~2s later — FCM fires
      // onTokenRefresh with the initial token.
      gateway.emitRefresh('fcm-late-arrival');
      await Future<void>.delayed(Duration.zero);

      expect(repo.added, hasLength(1));
      expect(repo.added.first.uid, 'u1');
      expect(repo.added.first.token, 'fcm-late-arrival');
    },
  );

  group('Phase 6.2 — platform-tagged token storage', () {
    test('default constructor tags writes as "mobile" under tests', () async {
      // `kIsWeb` is false in the Dart VM test runner, so the default
      // FcmService writes the mobile tag. Web tests inject explicitly.
      final ok = await service.attach(uid: 'u1');

      expect(ok, isTrue);
      expect(repo.added.single.platform, 'mobile');
    });

    test(
      'explicit platform: "web" propagates to both initial + refresh writes',
      () async {
        final webService = FcmService(
          gateway: gateway,
          userRepository: repo,
          notificationChannels: channels,
          platform: 'web',
        );

        final ok = await webService.attach(uid: 'u1');
        expect(ok, isTrue);
        expect(repo.added.single.platform, 'web');

        gateway.emitRefresh('fcm-token-refresh-web');
        await Future<void>.delayed(Duration.zero);

        expect(repo.added, hasLength(2));
        expect(repo.added.last.platform, 'web');

        await webService.detach(uid: 'u1');
        expect(repo.removed.single.platform, 'web');
        await webService.dispose();
      },
    );

    test('attach() threads vapidKey through to gateway.getToken()', () async {
      final webService = FcmService(
        gateway: gateway,
        userRepository: repo,
        notificationChannels: channels,
        platform: 'web',
        vapidKey: 'BVAPID_KEY_X',
      );

      final ok = await webService.attach(uid: 'u1');
      expect(ok, isTrue);
      expect(gateway.lastVapidKey, 'BVAPID_KEY_X');
      await webService.dispose();
    });
  });
}
