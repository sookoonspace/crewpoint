import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';

/// Stands in for the `createEvent` callable, writing what the server would.
/// Its validation is covered by `functions/test/events/createEvent.test.ts`.
CreateEventCall fakeCreateEventCall(FirebaseFirestore firestore) =>
    (event) async {
      final uid = event.creatorId;
      await firestore.collection('events').doc(event.id).set({
        'id': event.id,
        'title': event.title,
        'description': event.description,
        'eventType': event.eventType.name,
        'creatorId': uid,
        'adminIds': [uid],
        'memberIds': [uid],
        'status': 'active',
        'currency': event.currency,
        'startDate': event.startDate == null
            ? null
            : Timestamp.fromDate(event.startDate!),
        'endDate': event.endDate == null
            ? null
            : Timestamp.fromDate(event.endDate!),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    };
