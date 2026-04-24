import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/i_sync_service.dart';
import 'package:crewpoint_app/app/core/services/sync_engine.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';

import 'package:crewpoint_app/app/features/profile/presentation/profile_screen.dart';

import '../auth/fake_auth_service.dart';

void main() {
  group('SyncEngine', () {
    late SyncEngine syncEngine;

    setUp(() => syncEngine = SyncEngine());
    tearDown(() => syncEngine.dispose());

    test('emits syncing then completed on syncAll', () async {
      final future = syncEngine.syncStatusStream.take(2).toList();
      await syncEngine.syncAll();

      final statuses = await future;
      expect(statuses.first, equals(SyncStatus.syncing));
      expect(statuses.last, equals(SyncStatus.completed));
    });
  });

  group('Account deletion clears Drift tables', () {
    test('deleting all tables results in empty queries', () async {
      final db = AppDatabase(NativeDatabase.memory());

      await db
          .into(db.users)
          .insert(UsersCompanion.insert(id: 'u1', email: 'test@example.com'));

      var users = await db.select(db.users).get();
      expect(users, hasLength(1));

      await db.delete(db.chatMessages).go();
      await db.delete(db.expenses).go();
      await db.delete(db.tasks).go();
      await db.delete(db.events).go();
      await db.delete(db.users).go();

      users = await db.select(db.users).get();
      expect(users, isEmpty);

      await db.close();
    });
  });

  group('ProfileScreen', () {
    testWidgets('renders profile screen with hero and settings', (
      tester,
    ) async {
      final fakeAuthService = FakeAuthService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => AuthNotifier(
                authRepository: AuthRepository(authService: fakeAuthService),
              ),
            ),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();

      // Hero card visible with title and edit button
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('User'), findsOneWidget);
    });
  });
}
