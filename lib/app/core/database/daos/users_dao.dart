import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<List<User>> allUsers() => select(users).get();

  Future<User?> userById(String id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<int> insertUser(UsersCompanion entry) => into(users).insert(entry);

  Future<bool> updateUser(UsersCompanion entry) => update(users).replace(entry);

  Future<int> deleteUserById(String id) =>
      (delete(users)..where((u) => u.id.equals(id))).go();
}
