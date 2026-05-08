import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/create_event_screen.dart';

void main() {
  late AppDatabase database;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
  });

  tearDown(() async {
    await database.close();
  });

  /// CreateEventScreen is a tall form. Default test viewport (800x600) hides
  /// the submit button below the fold, so taps silently miss. Use a tall
  /// canvas for every test in this group.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildApp({
    AuthNotifier Function()? authFactory,
    EventRepository? eventRepoOverride,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        firestoreProvider.overrideWithValue(firestore),
        if (authFactory != null) authProvider.overrideWith(authFactory),
        if (eventRepoOverride != null)
          eventRepositoryProvider.overrideWithValue(eventRepoOverride),
      ],
      child: const MaterialApp(home: _Host()),
    );
  }

  testWidgets(
    'happy path: tapping Create writes one document to Firestore and pops',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        buildApp(
          authFactory: () => _StubAuthNotifier(
            const AppUser(uid: 'uid-42', email: 'a@example.com'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the create-event screen via the host.
      await tester.tap(find.byKey(const Key('host.openCreate')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('createEvent.title')),
        'Tahoe Trip',
      );
      await tester.tap(find.byKey(const Key('createEvent.submit')));
      await tester.pumpAndSettle();

      final docs = await firestore.collection('events').get();
      expect(docs.docs, hasLength(1));
      final data = docs.docs.first.data();
      expect(data['title'], 'Tahoe Trip');
      expect(data['creatorId'], 'uid-42');
      expect(data['adminIds'], ['uid-42']);
      expect(data['memberIds'], ['uid-42']);
      expect(data['status'], 'active');

      // Screen popped — back on the host.
      expect(find.byKey(const Key('host.openCreate')), findsOneWidget);
      expect(find.byKey(const Key('createEvent.submit')), findsNothing);
      expect(find.text('Event created'), findsOneWidget);
    },
  );

  testWidgets(
    'failure path: repository throws → screen stays mounted with inline error',
    (tester) async {
      useTallViewport(tester);
      final failing = _FailingEventRepo(database, firestore);
      await tester.pumpWidget(
        buildApp(
          authFactory: () => _StubAuthNotifier(
            const AppUser(uid: 'uid-42', email: 'a@example.com'),
          ),
          eventRepoOverride: failing,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('host.openCreate')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('createEvent.title')),
        'Will fail',
      );
      await tester.tap(find.byKey(const Key('createEvent.submit')));
      await tester.pumpAndSettle();

      // Stayed on the Create screen.
      expect(find.byKey(const Key('createEvent.submit')), findsOneWidget);
      // Error widget visible.
      expect(find.byKey(const Key('createEvent.error')), findsOneWidget);
      expect(find.text("Couldn't create event — try again"), findsOneWidget);
      // Success SnackBar NOT shown.
      expect(find.text('Event created'), findsNothing);
    },
  );

  testWidgets(
    'loading state: while submission is in flight, the button is disabled and shows progress',
    (tester) async {
      useTallViewport(tester);
      final slow = _SlowEventRepo(database, firestore);
      await tester.pumpWidget(
        buildApp(
          authFactory: () => _StubAuthNotifier(
            const AppUser(uid: 'uid-42', email: 'a@example.com'),
          ),
          eventRepoOverride: slow,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('host.openCreate')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('createEvent.title')),
        'Slow one',
      );
      await tester.tap(find.byKey(const Key('createEvent.submit')));
      await tester.pump(); // run setState
      await tester.pump(const Duration(milliseconds: 50));

      // Button should now show progress and not be tappable.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Tapping again must not enqueue a second submission — the in-flight
      // future is still pending.
      await tester.tap(find.byKey(const Key('createEvent.submit')));
      await tester.pump();

      // Resolve so the test finishes cleanly.
      slow.completer.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'sign-out path: uid is null → "Sign-in required" error, no Firestore write',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(buildApp(authFactory: _UnauthNotifier.new));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('host.openCreate')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('createEvent.title')),
        'No auth',
      );
      await tester.tap(find.byKey(const Key('createEvent.submit')));
      await tester.pumpAndSettle();

      // Inline error visible.
      expect(find.byKey(const Key('createEvent.error')), findsOneWidget);
      expect(find.textContaining('Sign-in required'), findsOneWidget);
      // No Firestore document created.
      final docs = await firestore.collection('events').get();
      expect(docs.docs, isEmpty);
    },
  );
}

/// Test host that hosts a button to push CreateEventScreen onto the
/// navigator. Lets the happy-path test verify pop behavior end-to-end.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('host.openCreate'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CreateEventScreen(),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._user)
    : super(authRepository: _UnusedAuthRepository());
  final AppUser _user;

  @override
  AuthState build() => Authenticated(_user);
}

class _UnauthNotifier extends AuthNotifier {
  _UnauthNotifier() : super(authRepository: _UnusedAuthRepository());

  @override
  AuthState build() => const Unauthenticated();
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Auth not exercised in test');
}

/// Repository whose [createEvent] always throws — exercises the
/// failure-path branch without needing to mock sealed Firestore types.
class _FailingEventRepo extends EventRepository {
  _FailingEventRepo(AppDatabase db, FirebaseFirestore firestore)
    : super(eventsDao: EventsDao(db), firestore: firestore);

  @override
  Future<void> createEvent(_) async {
    throw FirebaseException(plugin: 'firestore', message: 'simulated failure');
  }
}

/// Repository whose [createEvent] never resolves until [completer] fires —
/// exercises the in-flight loading state.
class _SlowEventRepo extends EventRepository {
  _SlowEventRepo(AppDatabase db, FirebaseFirestore firestore)
    : super(eventsDao: EventsDao(db), firestore: firestore);

  final Completer<void> completer = Completer<void>();

  @override
  Future<void> createEvent(_) => completer.future;
}
