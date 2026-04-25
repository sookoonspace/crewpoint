import 'dart:developer';

import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/repositories/i_event_repository.dart';

class EventRepository implements IEventRepository {
  const EventRepository({required EventsDao eventsDao})
    : _eventsDao = eventsDao;

  final EventsDao _eventsDao;

  @override
  Stream<List<EventModel>> watchAllEvents() {
    return _eventsDao.watchAllEvents().map(
      (rows) => rows.map(_toDomain).toList(),
    );
  }

  @override
  Future<List<EventModel>> getAllEvents() async {
    try {
      final rows = await _eventsDao.allEvents();
      return rows.map(_toDomain).toList();
    } catch (e, st) {
      log('Failed to get events', error: e, stackTrace: st, name: 'events');
      return [];
    }
  }

  @override
  Future<EventModel?> getEventById(String id) async {
    try {
      final row = await _eventsDao.eventById(id);
      return row != null ? _toDomain(row) : null;
    } catch (e, st) {
      log('Failed to get event $id', error: e, stackTrace: st, name: 'events');
      return null;
    }
  }

  @override
  Future<bool> createEvent(EventModel event) async {
    try {
      await _eventsDao.insertEvent(
        EventsCompanion.insert(
          id: event.id,
          title: event.title,
          creatorId: event.creatorId,
          startDate: event.startDate,
          description: Value(event.description),
          endDate: Value(event.endDate),
          location: Value(event.location),
        ),
      );
      return true;
    } catch (e, st) {
      log('Failed to create event', error: e, stackTrace: st, name: 'events');
      return false;
    }
  }

  @override
  Future<bool> deleteEvent(String id) async {
    try {
      await _eventsDao.deleteEventById(id);
      return true;
    } catch (e, st) {
      log(
        'Failed to delete event $id',
        error: e,
        stackTrace: st,
        name: 'events',
      );
      return false;
    }
  }

  EventModel _toDomain(Event row) => EventModel(
    id: row.id,
    title: row.title,
    description: row.description,
    creatorId: row.creatorId,
    startDate: row.startDate,
    endDate: row.endDate,
    location: row.location,
    status: EventStatus.values.firstWhere(
      (s) => s.name == row.status,
      orElse: () => EventStatus.active,
    ),
  );
}
