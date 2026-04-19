/// Domain model for an event.
class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.creatorId,
    required this.startDate,
    this.description,
    this.endDate,
    this.location,
    this.status = EventStatus.active,
  });

  final String id;
  final String title;
  final String? description;
  final String creatorId;
  final DateTime startDate;
  final DateTime? endDate;
  final String? location;
  final EventStatus status;
}

enum EventStatus { active, completed, cancelled }
