import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Abstract event repository.
abstract class IEventRepository {
  Stream<List<EventModel>> watchAllEvents();
  Future<List<EventModel>> getAllEvents();
  Future<EventModel?> getEventById(String id);
  Future<bool> createEvent(EventModel event);
  Future<bool> deleteEvent(String id);
}
