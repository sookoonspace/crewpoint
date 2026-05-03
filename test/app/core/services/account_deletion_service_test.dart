import 'package:cloud_functions/cloud_functions.dart';
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

      expect(
        result.errorCode,
        isNull,
        reason: 'success path returns errorCode == null',
      );
      expect(result.message, isNull);
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
      result.errorCode,
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

  test(
    'maps a Cloud Function firestore-stage failure to firestoreCleanupFailedCode',
    () async {
      final service = AccountDeletionService(
        database: db,
        secureStorage: storage,
        firebaseAuth: auth,
        deletionCallable: () async {
          throw FirebaseFunctionsException(
            code: 'internal',
            message: 'Account deletion failed',
            details: const <String, dynamic>{'stage': 'firestore'},
          );
        },
      );

      final result = await service.executeAccountDeletion();

      expect(
        result.errorCode,
        equals(AccountDeletionService.firestoreCleanupFailedCode),
      );
      expect(
        result.message,
        contains('your data'),
        reason: 'firestore-stage message must reference data, not auth.',
      );
    },
  );

  test(
    'maps an unauthenticated Cloud Function failure to unauthenticatedCode',
    () async {
      final service = AccountDeletionService(
        database: db,
        secureStorage: storage,
        firebaseAuth: auth,
        deletionCallable: () async {
          throw FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Must be authenticated',
          );
        },
      );

      final result = await service.executeAccountDeletion();

      expect(
        result.errorCode,
        equals(AccountDeletionService.unauthenticatedCode),
      );
      expect(result.message, contains('sign in'));
    },
  );

  test('falls back to unknownCode when no stage is reported', () async {
    final service = AccountDeletionService(
      database: db,
      secureStorage: storage,
      firebaseAuth: auth,
      deletionCallable: () async {
        throw FirebaseFunctionsException(
          code: 'internal',
          message: 'Generic failure',
          // No details / no stage.
        );
      },
    );

    final result = await service.executeAccountDeletion();

    expect(result.errorCode, equals(AccountDeletionService.unknownCode));
    expect(result.message, contains('Generic failure'));
  });

  test(
    'maps a Cloud Function auth-stage failure to authDeleteFailedCode',
    () async {
      final service = AccountDeletionService(
        database: db,
        secureStorage: storage,
        firebaseAuth: auth,
        deletionCallable: () async {
          throw FirebaseFunctionsException(
            code: 'internal',
            message: 'Account deletion failed',
            details: const <String, dynamic>{'stage': 'auth'},
          );
        },
      );

      final result = await service.executeAccountDeletion();

      expect(
        result.errorCode,
        equals(AccountDeletionService.authDeleteFailedCode),
      );
      expect(
        result.message,
        contains('your account'),
        reason:
            'auth-stage failure must surface a stage-specific message — '
            'not the generic "Account deletion failed" copy.',
      );
    },
  );
}
