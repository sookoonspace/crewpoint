import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';

import 'member_docs.dart';

/// Stands in for the `createEvent` callable, writing what the server would.
/// Its validation is covered by `functions/test/events/createEvent.test.ts`.
CreateEventCall fakeCreateEventCall(FirebaseFirestore firestore) =>
    (event) async {
      final uid = event.creatorId;
      // The template, read from the same file the server copies (Req 62).
      final template =
          jsonDecode(
                File(
                  'assets/templates/${event.templateId}.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final field in template['fields'] as List<dynamic>) {
        final f = Map<String, dynamic>.of(field as Map<String, dynamic>);
        await firestore
            .doc('events/${event.id}/fields/${f.remove('id')}')
            .set(f);
      }
      // The server writes the owner's member document in the same transaction.
      await firestore.doc('events/${event.id}/members/$uid').set({
        'uid': uid,
        'roleIds': ['owner'],
        'permissions': legacyPermissions('owner'),
      });
      await firestore.collection('events').doc(event.id).set({
        'id': event.id,
        'title': event.title,
        'description': event.description,
        'templateId': event.templateId,
        'templateVersion': template['version'],
        'creatorId': uid,
        'organizerId': uid,
        'adminIds': [uid],
        'memberIds': [uid],
        'memberCount': 1,
        'status': 'draft',
        'currency': event.currency,
        'timeZone': event.timeZone,
        'dateOnly': event.dateOnly,
        'venues': <Object>[],
        'languages': ['en'],
        'modules': {
          'tasks': true,
          'budget': true,
          'chat': true,
          'schedule': true,
          ...template['modules'] as Map<String, dynamic>,
        },
        'labels': template['labels'],
        'settings': template['settings'],
        'capacity': null,
        'memberLimit': null,
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
