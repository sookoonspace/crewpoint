import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/event_tasks_page.dart';

/// Forces an `Authenticated` state without going through Firebase auth.
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._user)
    : super(authRepository: _UnusedAuthRepository());
  final AppUser _user;

  @override
  AuthState build() => Authenticated(_user);
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Auth not used in test harness');
}

class TasksHarness {
  TasksHarness({
    required this.event,
    required this.currentUser,
    FakeFirebaseFirestore? firestore,
    AppDatabase? database,
  }) : firestore = firestore ?? FakeFirebaseFirestore(),
       database = database ?? AppDatabase(NativeDatabase.memory());

  final EventModel event;
  final AppUser currentUser;
  final FakeFirebaseFirestore firestore;
  final AppDatabase database;
  final List<Map<String, String>> markCompleteCalls = [];

  Future<void> seed() async {
    await UsersDao(database).insertUser(
      UsersCompanion.insert(id: currentUser.uid, email: currentUser.email),
    );
    await EventsDao(database).insertEvent(
      EventsCompanion.insert(
        id: event.id,
        title: event.title,
        creatorId: event.creatorId,
        startDate: const Value.absent(),
      ),
    );
  }

  TaskRepository get repository => TaskRepository(
    tasksDao: TasksDao(database),
    firestore: firestore,
    markTaskComplete: ({required eventId, required taskId}) async {
      markCompleteCalls.add({'eventId': eventId, 'taskId': taskId});
      await firestore
          .collection('events')
          .doc(eventId)
          .collection('tasks')
          .doc(taskId)
          .update({'status': 'done', 'completedBy': currentUser.uid});
    },
  );

  Widget buildApp() {
    final repo = repository;
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        firestoreProvider.overrideWithValue(firestore),
        taskRepositoryProvider.overrideWithValue(repo),
        authProvider.overrideWith(() => _StubAuthNotifier(currentUser)),
      ],
      child: MaterialApp(home: EventTasksPage(event: event)),
    );
  }
}
