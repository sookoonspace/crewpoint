import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

class DashboardNotifier extends Notifier<List<EventModel>> {
  DashboardNotifier({required EventRepository eventRepository})
    : _eventRepository = eventRepository;

  final EventRepository _eventRepository;
  StreamSubscription<List<EventModel>>? _subscription;

  @override
  List<EventModel> build() {
    _subscription?.cancel();
    _subscription = _eventRepository.watchAllEvents().listen(
      (events) => state = events,
    );
    ref.onDispose(() => _subscription?.cancel());
    return [];
  }

  Future<bool> createEvent(EventModel event) async {
    return _eventRepository.createEvent(event);
  }

  Future<bool> deleteEvent(String id) async {
    return _eventRepository.deleteEvent(id);
  }
}
