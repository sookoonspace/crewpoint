import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/fcm_gateway.dart';
import 'package:crewpoint_app/app/core/services/fcm_service.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

class _FakeFcmGateway implements IFcmGateway {
  bool permissionGranted = true;
  String? apnsToken = 'apns-1';
  String? currentToken = 'fcm-token-A';
  final _refreshController = StreamController<String>.broadcast();
  bool deleted = false;
  int permissionCalls = 0;
  int getTokenCalls = 0;

  @override
  Future<String?> getApnsToken() async => apnsToken;

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
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
  final List<({String uid, String token})> added = [];
  final List<({String uid, String token})> removed = [];

  @override
  Future<void> addFcmToken({required String uid, required String token}) async {
    added.add((uid: uid, token: token));
  }

  @override
  Future<void> removeFcmToken({
    required String uid,
    required String token,
  }) async {
    removed.add((uid: uid, token: token));
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
}

void main() {
  late _FakeFcmGateway gateway;
  late _FakeUserRepo repo;
  late FcmService service;

  setUp(() {
    gateway = _FakeFcmGateway();
    repo = _FakeUserRepo();
    service = FcmService(gateway: gateway, userRepository: repo);
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
}
