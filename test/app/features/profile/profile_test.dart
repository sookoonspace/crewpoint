import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/services/i_sync_service.dart';
import 'package:crewpoint_app/app/core/services/sync_engine.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/presentation/profile_screen.dart';

void main() {
  group('SyncEngine', () {
    late SyncEngine syncEngine;

    setUp(() => syncEngine = SyncEngine());
    tearDown(() => syncEngine.dispose());

    test('emits syncing then completed on syncAll', () async {
      // Collect statuses before starting sync
      final future = syncEngine.syncStatusStream.take(2).toList();

      // Start sync - it emits syncing then completed
      await syncEngine.syncAll();

      final statuses = await future;
      expect(statuses.first, equals(SyncStatus.syncing));
      expect(statuses.last, equals(SyncStatus.completed));
    });
  });

  group('Account deletion clears Drift tables', () {
    test('deleting all tables results in empty queries', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // Insert test data
      await db
          .into(db.users)
          .insert(UsersCompanion.insert(id: 'u1', email: 'test@example.com'));

      // Verify data exists
      var users = await db.select(db.users).get();
      expect(users, hasLength(1));

      // Simulate account deletion by clearing all tables
      await db.delete(db.chatMessages).go();
      await db.delete(db.expenses).go();
      await db.delete(db.tasks).go();
      await db.delete(db.events).go();
      await db.delete(db.users).go();

      // Verify all tables empty
      users = await db.select(db.users).get();
      expect(users, isEmpty);

      await db.close();
    });
  });

  group('ProfileScreen', () {
    testWidgets('displays user info', (tester) async {
      const user = AppUser(
        uid: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      await tester.pumpWidget(
        const MaterialApp(home: ProfileScreen(user: user)),
      );

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows delete account option', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

      expect(find.text('Delete Account'), findsOneWidget);
    });
  });
}
