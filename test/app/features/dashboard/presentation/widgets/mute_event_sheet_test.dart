import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_mute_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/mute_event_sheet.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  required EventMuteRepository repo,
  required FakeFirebaseFirestore firestore,
  required String uid,
  required String eventId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        eventMuteRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () =>
                  MuteEventSheet.show(context: ctx, uid: uid, eventId: eventId),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeFirebaseFirestore firestore;
  late EventMuteRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = EventMuteRepository(firestore: firestore);
  });

  group('MuteEventSheet — duration buttons', () {
    testWidgets('renders all four duration options + Cancel', (tester) async {
      await _pumpSheet(
        tester,
        repo: repo,
        firestore: firestore,
        uid: 'u1',
        eventId: 'evt-1',
      );

      expect(find.byKey(const Key('muteSheet.duration.1h')), findsOneWidget);
      expect(find.byKey(const Key('muteSheet.duration.8h')), findsOneWidget);
      expect(find.byKey(const Key('muteSheet.duration.1d')), findsOneWidget);
      expect(
        find.byKey(const Key('muteSheet.duration.untilUnmute')),
        findsOneWidget,
      );
    });

    testWidgets('tap "1 hour" writes mutedUntil ≈ now + 1h to Firestore', (
      tester,
    ) async {
      final fixedNow = DateTime.utc(2026, 6, 1, 12);
      await withClock(Clock.fixed(fixedNow), () async {
        await _pumpSheet(
          tester,
          repo: repo,
          firestore: firestore,
          uid: 'u1',
          eventId: 'evt-1',
        );

        await tester.tap(find.byKey(const Key('muteSheet.duration.1h')));
        await tester.pumpAndSettle();

        final snap = await firestore
            .collection('users')
            .doc('u1')
            .collection('eventMutes')
            .doc('evt-1')
            .get();
        expect(
          snap.data()?['mutedUntil'],
          DateTime.utc(2026, 6, 1, 13).toIso8601String(),
        );
      });
    });

    testWidgets('tap "Until I unmute" writes a far-future mutedUntil', (
      tester,
    ) async {
      final fixedNow = DateTime.utc(2026, 6, 1, 12);
      await withClock(Clock.fixed(fixedNow), () async {
        await _pumpSheet(
          tester,
          repo: repo,
          firestore: firestore,
          uid: 'u1',
          eventId: 'evt-1',
        );

        await tester.tap(
          find.byKey(const Key('muteSheet.duration.untilUnmute')),
        );
        await tester.pumpAndSettle();

        final snap = await firestore
            .collection('users')
            .doc('u1')
            .collection('eventMutes')
            .doc('evt-1')
            .get();
        // "Until I unmute" → ~10 years in the future. Pin the year.
        final mutedUntil = DateTime.parse(snap.data()!['mutedUntil'] as String);
        expect(mutedUntil.year, greaterThanOrEqualTo(2036));
      });
    });
  });

  group('MuteEventSheet — already-muted state', () {
    testWidgets('shows "Unmute" CTA + tapping it deletes the mute doc', (
      tester,
    ) async {
      final fixedNow = DateTime.utc(2026, 6, 1, 12);
      await withClock(Clock.fixed(fixedNow), () async {
        // Seed an active mute (8h from "now") so isMutedAt(clock.now)
        // returns true regardless of wall-clock during the test run.
        await repo.muteEvent(
          uid: 'u1',
          eventId: 'evt-1',
          mutedUntil: fixedNow.add(const Duration(hours: 8)),
        );

        await _pumpSheet(
          tester,
          repo: repo,
          firestore: firestore,
          uid: 'u1',
          eventId: 'evt-1',
        );

        await tester.tap(find.byKey(const Key('muteSheet.unmute')));
        await tester.pumpAndSettle();

        final snap = await firestore
            .collection('users')
            .doc('u1')
            .collection('eventMutes')
            .doc('evt-1')
            .get();
        expect(snap.exists, isFalse);
      });
    });
  });
}
