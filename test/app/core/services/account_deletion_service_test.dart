import 'package:drift/native.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/services/account_deletion_service.dart';
import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';
import 'package:crewpoint_app/app/features/onboarding/application/onboarding_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SecureStorageService storage;
  late MockFirebaseAuth auth;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    storage = SecureStorageService();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'u1@example.com'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'executeAccountDeletion re-pins onboarding_complete=true after deleteAll '
    'so the next sign-up does not force the user back through onboarding',
    () async {
      final service = AccountDeletionService(
        database: db,
        secureStorage: storage,
        firebaseAuth: auth,
        deletionCallable: () async {
          /* CF success stub */
        },
      );

      // Pretend the user already finished onboarding before deletion.
      await storage.write(key: onboardingCompleteKey, value: 'true');

      final result = await service.executeAccountDeletion();

      expect(result, isNull, reason: 'success path returns null today');
      expect(
        await storage.read(onboardingCompleteKey),
        equals('true'),
        reason:
            'deleteAll wipes the key; the service must re-pin it before '
            'returning so the global router does not redirect to /onboarding '
            'on the next cold launch.',
      );
    },
  );

  test('a Drift wipe failure does NOT prevent the secure-storage re-pin — '
      'flag preservation is the last step', () async {
    // Closing the DB before _clearLocalData runs makes every Drift
    // delete throw. The service should swallow those errors and still
    // reach the secure-storage cleanup + re-pin.
    await db.close();

    final service = AccountDeletionService(
      database: db,
      secureStorage: storage,
      firebaseAuth: auth,
      deletionCallable: () async {
        /* CF success stub */
      },
    );

    await storage.write(key: onboardingCompleteKey, value: 'true');

    final result = await service.executeAccountDeletion();

    expect(
      result,
      isNull,
      reason:
          'local-data clear failure must NOT flip success result to '
          'failure — server-side state is the source of truth.',
    );
    expect(
      await storage.read(onboardingCompleteKey),
      equals('true'),
      reason:
          'flag preservation is the last step; Drift failure happens '
          'inside an inner try/catch and execution continues.',
    );

    // Re-open the DB so the tearDown's db.close() does not throw on
    // an already-closed connection.
    db = AppDatabase(NativeDatabase.memory());
  });
}
