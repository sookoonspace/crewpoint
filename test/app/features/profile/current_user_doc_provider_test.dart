import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/application/current_user_doc_provider.dart';

import '../auth/fake_auth_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAuthService fakeAuthService;
  late ProviderContainer container;

  const testAuthUser = AuthUser(
    uid: 'uid-1',
    email: 'jane@example.com',
    // displayName intentionally null — simulates Apple subsequent login.
    photoUrl: null,
    providerIds: ['apple.com'],
  );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    fakeAuthService = FakeAuthService();
    final authRepository = AuthRepository(authService: fakeAuthService);
    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        authProvider.overrideWith(
          () => AuthNotifier(authRepository: authRepository),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeAuthService.dispose();
  });

  test('emits null when unauthenticated', () async {
    final user = await _waitFor(
      container,
      (async) => async.hasValue && async.value == null,
    );
    expect(user, isNull);
  });

  test('falls back to Firebase Auth metadata when public doc has not been '
      'materialised yet', () async {
    fakeAuthService.setCurrentUser(testAuthUser);
    container.read(authProvider); // ensure notifier subscribes to stream

    final user = await _waitFor(
      container,
      (async) => async.hasValue && async.value?.uid == 'uid-1',
    );
    expect(user, isNotNull);
    expect(user!.email, equals('jane@example.com'));
    expect(user.displayName, isNull); // Auth had no displayName
    expect(user.providerIds, equals(['apple.com']));
  });

  test('merges Firestore public doc fields with Firebase Auth identity '
      'after createUserIfNotExists writes the doc', () async {
    await firestore.collection('users').doc('uid-1').set({
      'displayName': 'Jane',
      'photoUrl': null,
      'paymentMethod': 'venmo',
      'paymentHandle': '@jane',
    });

    fakeAuthService.setCurrentUser(testAuthUser);
    container.read(authProvider);

    final user = await _waitFor(
      container,
      (async) => async.value?.displayName == 'Jane',
    );
    expect(user!.email, equals('jane@example.com')); // from Auth
    expect(user.paymentMethod, equals('venmo'));
    expect(user.paymentHandle, equals('@jane'));
    expect(user.providerIds, equals(['apple.com'])); // from Auth
  });

  test('re-emits when Firestore doc updates (live profile edits)', () async {
    await firestore.collection('users').doc('uid-1').set({
      'displayName': 'Old Name',
    });

    fakeAuthService.setCurrentUser(testAuthUser);
    container.read(authProvider);

    final beforeUpdate = await _waitFor(
      container,
      (async) => async.value?.displayName == 'Old Name',
    );
    expect(beforeUpdate!.displayName, equals('Old Name'));

    await firestore.collection('users').doc('uid-1').set({
      'displayName': 'New Name',
    }, SetOptions(merge: true));

    final afterUpdate = await _waitFor(
      container,
      (async) => async.value?.displayName == 'New Name',
    );
    expect(afterUpdate!.displayName, equals('New Name'));
  });
}

/// Listens to [currentUserDocProvider] until [predicate] matches the
/// emitted [AsyncValue], with a short timeout to keep failing tests
/// bounded. Returns the matching [AppUser?].
Future<AppUser?> _waitFor(
  ProviderContainer container,
  bool Function(AsyncValue<AppUser?>) predicate,
) async {
  final completer = Completer<AppUser?>();
  final sub = container.listen<AsyncValue<AppUser?>>(currentUserDocProvider, (
    _,
    next,
  ) {
    if (predicate(next) && !completer.isCompleted) {
      completer.complete(next.value);
    }
  }, fireImmediately: true);
  try {
    return await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw TimeoutException('predicate never matched', null),
    );
  } finally {
    sub.close();
  }
}
