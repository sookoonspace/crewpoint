import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  late AppDatabase db;
  late EventRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final usersDao = UsersDao(db);
    await usersDao.insertUser(
      UsersCompanion.insert(id: 'user-1', email: 'test@example.com'),
    );
    repository = EventRepository(eventsDao: EventsDao(db));
  });

  tearDown(() => db.close());

  test('saves event to Drift and retrieves it', () async {
    final event = EventModel(
      id: 'event-1',
      title: 'Team Meetup',
      creatorId: 'user-1',
      startDate: DateTime(2026, 6, 1),
      description: 'Quarterly sync',
    );

    final created = await repository.createEvent(event);
    expect(created, isTrue);

    final result = await repository.getEventById('event-1');
    expect(result, isNotNull);
    expect(result!.title, equals('Team Meetup'));
    expect(result.description, equals('Quarterly sync'));
  });

  test('streams events reactively on insert', () async {
    final stream = repository.watchAllEvents();

    // First emission: empty
    final firstEmission = await stream.first;
    expect(firstEmission, isEmpty);

    // Insert an event
    await repository.createEvent(
      EventModel(
        id: 'event-1',
        title: 'New Event',
        creatorId: 'user-1',
        startDate: DateTime(2026, 6, 1),
      ),
    );

    // Next emission should include the event
    final secondEmission = await stream.first;
    expect(secondEmission, hasLength(1));
    expect(secondEmission.first.title, equals('New Event'));
  });

  test('returns empty list when no events', () async {
    final events = await repository.getAllEvents();
    expect(events, isEmpty);
  });
}
