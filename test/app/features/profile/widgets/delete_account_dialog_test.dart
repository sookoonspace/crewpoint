import 'dart:async';

import 'package:drift/native.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/account_deletion_service.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/delete_account_dialog.dart';

import '../../auth/fake_auth_service.dart';

/// Recording subclass of [AccountDeletionService] so tests can drive
/// `currentAuthProvider`, the re-auth booleans, and the CF result
/// without standing up a full Firebase / Cloud Functions stack.
class _RecordingDeletionService extends AccountDeletionService {
  _RecordingDeletionService({
    required super.database,
    required super.secureStorage,
  }) : super(
         firebaseAuth: MockFirebaseAuth(signedIn: true),
         deletionCallable: _neverCalled,
       );

  static Future<void> _neverCalled() async {
    throw StateError(
      'tests should not reach the wrapped callable; the recording '
      'service overrides executeAccountDeletion directly.',
    );
  }

  AuthProviderType providerOverride = AuthProviderType.email;
  bool reAuthShouldSucceed = true;
  ({String? errorCode, String? message}) deletionResult = (
    errorCode: null,
    message: null,
  );

  /// When non-null, [executeAccountDeletion] awaits this completer
  /// before returning [deletionResult]. Used by the auth-flip-on-step-2
  /// test to keep the CF call in flight while the auth state changes.
  Completer<void>? deletionGate;

  int reAuthEmailCalls = 0;
  int reAuthGoogleCalls = 0;
  int reAuthAppleCalls = 0;
  int executeCalls = 0;
  String? lastEmailPassword;

  @override
  AuthProviderType get currentAuthProvider => providerOverride;

  @override
  Future<bool> reAuthenticateWithEmail(String password) async {
    reAuthEmailCalls++;
    lastEmailPassword = password;
    return reAuthShouldSucceed;
  }

  @override
  Future<bool> reAuthenticateWithGoogle() async {
    reAuthGoogleCalls++;
    return reAuthShouldSucceed;
  }

  @override
  Future<bool> reAuthenticateWithApple() async {
    reAuthAppleCalls++;
    return reAuthShouldSucceed;
  }

  @override
  Future<({String? errorCode, String? message})>
  executeAccountDeletion() async {
    executeCalls++;
    if (deletionGate != null) {
      await deletionGate!.future;
    }
    return deletionResult;
  }
}

class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (innerContext) => Center(
            child: ElevatedButton(
              key: const Key('open.delete.dialog'),
              onPressed: () => DeleteAccountDialog.show(context: innerContext),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<({_RecordingDeletionService service, FakeAuthService auth})>
_pumpAndOpenDialog(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({});
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final storage = SecureStorageService();
  final service = _RecordingDeletionService(
    database: db,
    secureStorage: storage,
  );
  final fakeAuth = FakeAuthService();
  addTearDown(fakeAuth.dispose);
  // Seed an authenticated user so AuthNotifier starts in Authenticated.
  fakeAuth.setCurrentUser(
    const AuthUser(uid: 'u1', email: 'u1@example.com', emailVerified: true),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountDeletionServiceProvider.overrideWithValue(service),
        authProvider.overrideWith(
          () => AuthNotifier(
            authRepository: AuthRepository(authService: fakeAuth),
          ),
        ),
      ],
      child: const _Harness(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('open.delete.dialog')));
  await tester.pumpAndSettle();

  return (service: service, auth: fakeAuth);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('step 0 → tap Continue → re-auth step is visible', (
    tester,
  ) async {
    await _pumpAndOpenDialog(tester);

    expect(find.byKey(const Key('deleteAccount.dialog.warn')), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('deleteAccount.dialog.reauth')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('deleteAccount.dialog.processing')),
      findsNothing,
      reason:
          'processing must NOT appear until re-auth succeeds — '
          'flipping early causes the loader to flash during the '
          'OAuth sheet.',
    );
  });

  testWidgets(
    'empty password rejects re-auth and the Cloud Function is never called',
    (tester) async {
      final harness = await _pumpAndOpenDialog(tester);
      harness.service.providerOverride = AuthProviderType.email;
      harness.service.reAuthShouldSucceed = false;

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Empty password.
      await tester.tap(find.text('Delete Forever'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('deleteAccount.dialog.reauth')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('deleteAccount.dialog.processing')),
        findsNothing,
      );
      expect(
        harness.service.executeCalls,
        equals(0),
        reason:
            'CF must never run without successful re-auth — empty password '
            'short-circuits before the email re-auth helper is even called.',
      );
    },
  );

  testWidgets('on Cloud Function success the dialog stays on step 2 (no manual '
      'Navigator.pop, no context.go) — the global redirect handles teardown', (
    tester,
  ) async {
    final harness = await _pumpAndOpenDialog(tester);
    harness.service.providerOverride = AuthProviderType.email;
    harness.service.reAuthShouldSucceed = true;
    harness.service.deletionResult = (errorCode: null, message: null);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'correct-password');
    await tester.tap(find.text('Delete Forever'));
    // Drain microtasks; can't pumpAndSettle because LoadingAnimation
    // animates forever on step 2.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // CF resolved via the recording fake; per the spec the dialog
    // stays on step 2 and lets the global authProvider redirect tear
    // it down. The dialog itself must NOT have called Navigator.pop.
    expect(harness.service.executeCalls, equals(1));
    expect(
      find.byKey(const Key('deleteAccount.dialog.processing')),
      findsOneWidget,
      reason:
          'after CF success the dialog stays at step 2 — Navigator.pop '
          'and context.go are forbidden on the success path.',
    );
  });

  testWidgets('on Cloud Function failure the dialog rolls back to step 1 with '
      'the typed error message', (tester) async {
    final harness = await _pumpAndOpenDialog(tester);
    harness.service.providerOverride = AuthProviderType.email;
    harness.service.reAuthShouldSucceed = true;
    harness.service.deletionResult = (
      errorCode: AccountDeletionService.authDeleteFailedCode,
      message: 'Your data was deleted but we could not finish.',
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'correct-password');
    await tester.tap(find.text('Delete Forever'));
    // Drain microtasks; the failure path rolls back to step 1 (no more
    // LoadingAnimation), so pumpAndSettle is safe AFTER the drain.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('deleteAccount.dialog.reauth')),
      findsOneWidget,
      reason: 'CF failure should roll back to the re-auth step.',
    );
    expect(
      find.text('Your data was deleted but we could not finish.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'auth-state flip to Unauthenticated while on step 0/1 dismisses the '
    'dialog (token expired or user signed out elsewhere)',
    (tester) async {
      final harness = await _pumpAndOpenDialog(tester);

      // Sit on step 0. Flip auth state externally.
      expect(
        find.byKey(const Key('deleteAccount.dialog.warn')),
        findsOneWidget,
      );

      harness.auth.setCurrentUser(null);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('deleteAccount.dialog.warn')),
        findsNothing,
        reason: 'the listener pops the dialog when auth flips on step 0/1.',
      );
    },
  );

  testWidgets(
    'auth-state flip to Unauthenticated while on step 2 does NOT pop the '
    'dialog — the global GoRouter redirect handles teardown',
    (tester) async {
      final harness = await _pumpAndOpenDialog(tester);
      harness.service.providerOverride = AuthProviderType.email;
      harness.service.reAuthShouldSucceed = true;
      // Hold the deletion future open so the dialog stays on step 2
      // while we flip the auth state.
      final gate = Completer<void>();
      harness.service.deletionGate = gate;

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'correct-password');
      await tester.tap(find.text('Delete Forever'));
      // Drain microtasks (LoadingAnimation animates forever; can't
      // pumpAndSettle here).
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Now on step 2 with the CF call gated open.
      expect(
        find.byKey(const Key('deleteAccount.dialog.processing')),
        findsOneWidget,
      );

      // Flip auth state. The dialog's listener short-circuits because
      // _step > 1 — no Navigator.pop fires from the dialog.
      harness.auth.setCurrentUser(null);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('deleteAccount.dialog.processing')),
        findsOneWidget,
        reason:
            'step-2 listener must short-circuit; the dialog has no '
            'business racing the global redirect.',
      );

      // Release the CF future so the test cleans up cleanly.
      gate.complete();
      // Drain microtasks; the dialog's success path is `if (!mounted)
      // return;` followed by no setState — no animations to settle.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    },
  );
}
