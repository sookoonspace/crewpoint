import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'events_dao.g.dart';

@DriftAccessor(tables: [Events])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  Future<List<Event>> allEvents() => select(events).get();

  Stream<List<Event>> watchAllEvents() => select(events).watch();

  Future<Event?> eventById(String id) =>
      (select(events)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> insertEvent(EventsCompanion entry) => into(events).insert(entry);

  Future<bool> updateEvent(EventsCompanion entry) =>
      update(events).replace(entry);

  Future<int> deleteEventById(String id) =>
      (delete(events)..where((e) => e.id.equals(id))).go();
}
