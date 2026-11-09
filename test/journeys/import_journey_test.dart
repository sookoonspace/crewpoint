import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';

import '../harness/fake_import.dart';
import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #77 (Req 44, 45, 75; X-01, X-02, X-03, X-06): an organizer imports a
/// roster with errors, then re-imports it, and confirms a missing family as
/// cancelled. The server's checks are tested in `functions/test/imports/`;
/// here [FakeImportServer] answers each job with a report.
void main() {
  late RolesHarness harness;
  late FakeFilePicker picker;
  late FakeImportUploader uploader;
  late FakeImportServer server;
  const e = 'events/${RolesHarness.eventId}';
  const route = '/dashboard/event/${RolesHarness.eventId}/people/import';

  const first =
      'Registration ID,Family,Full name,Age,Diet\n'
      'P1,Patel,Ravi Patel,42,Jain\n'
      'P2,Patel,Mira Patel,40,\n'
      'J1,Joshi,Ila Joshi,35,Veg\n';
  const second =
      'Registration ID,Family,Full name,Age,Diet\n'
      'P1,Patel,Ravi Patel,42,Veg\n'
      'P2,Patel,Mira Patel,40,Jain\n';

  Map<String, Object?> report({
    int total = 3,
    int valid = 2,
    int creates = 2,
    int updates = 0,
    List<Map<String, Object?>> errors = const [],
    List<Map<String, Object?>> missing = const [],
  }) => {
    'total': total,
    'valid': valid,
    'creates': creates,
    'updates': updates,
    'newGroups': 2,
    'errorCount': errors.length,
    'errors': errors,
    'mappingProblems': <String>[],
    'missingGroups': missing,
  };

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    String location = route,
    Size size = const Size(375, 1800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: location);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'lead': const ['crewLead'],
      },
    );
    // A convention calls its groups families, so the export's Family column
    // maps without help.
    await harness.firestore.doc(e).update({
      'labels': {
        'group': {'one': 'Family', 'other': 'Families'},
      },
    });
    await harness.firestore.doc('$e/fields/diet').set({
      'label': 'Diet',
      'type': 'singleChoice',
      'options': ['Jain', 'Veg'],
      'required': true,
      'scope': 'participant',
      'visibility': 'standard',
      'order': 0,
    });
    picker = FakeFilePicker();
    uploader = FakeImportUploader();
    server = FakeImportServer(
      harness.firestore,
      RolesHarness.eventId,
      respond: (job) {
        final reimport = job['fileName'] == 'second.csv';
        if (job['mode'] == 'dryRun') {
          return [
            {'status': 'running'},
            {
              'status': 'checked',
              'report': reimport
                  ? report(
                      total: 2,
                      valid: 2,
                      creates: 0,
                      updates: 2,
                      missing: [
                        {
                          'groupId': 'gJ',
                          'name': 'Joshi',
                          'participantIds': ['j1'],
                        },
                      ],
                    )
                  : report(
                      errors: [
                        {'row': 3, 'column': 'Diet', 'problem': 'required'},
                      ],
                    ),
            },
          ];
        }
        return [
          {
            'status': 'running',
            'progress': {'processed': 1, 'total': 2},
          },
          {
            'status': 'done',
            'progress': {'processed': 2, 'total': 2},
          },
        ];
      },
    );
    addTearDown(server.dispose);
    await tester.pumpWidget(
      harness.buildApp(
        overrides: [
          filePickerProvider.overrideWithValue(picker),
          importUploaderProvider.overrideWithValue(uploader),
        ],
      ),
    );
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  testWidgets(
    'X-06 an import with errors lists them, then imports the good rows',
    (tester) async {
      final robot = await open(tester);
      expect(find.byKey(const Key('people.import.online')), findsOneWidget);
      picker.add('first.csv', first);
      await robot.tap(const Key('people.import.pick'));
      expect(find.text('first.csv · 3 rows'), findsOneWidget);
      // The usual column names are already mapped.
      for (final (i, label) in [(0, 'ID from the other tool'), (1, 'Group')]) {
        expect(
          find.descendant(
            of: find.byKey(Key('people.import.map.$i')),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      await robot.tap(const Key('people.import.check'));
      await robot.settle();
      expect(uploader.uploads.keys.single, endsWith('.csv'));
      expect(server.queued.single['targets'], [
        'externalId',
        'group',
        'name',
        'age',
        'field:diet',
      ]);
      expect(
        find.text('2 of 3 rows are ready, 1 need fixing.'),
        findsOneWidget,
      );
      expect(find.text('Row 3, Diet: missing'), findsOneWidget);
      await robot.tap(const Key('people.import.apply'));
      await robot.settle();
      expect(find.text('Imported: 2 added and 0 updated.'), findsOneWidget);
      await robot.finish();
    },
  );

  testWidgets('X-02 X-03 a re-import updates people and lists a missing '
      'family, which can be marked cancelled', (tester) async {
    final robot = await open(tester);
    await harness.firestore.doc('$e/groups/gJ').set({
      'name': 'Joshi',
      'sortName': 'joshi',
      'adultUids': <String>[],
    });
    await harness.firestore.doc('$e/participants/j1').set({
      'name': 'Ila Joshi',
      'sortName': 'ila joshi',
      'groupId': 'gJ',
      'isChild': false,
      'status': 'active',
    });
    picker.add('second.csv', second);
    await robot.tap(const Key('people.import.pick'));
    await robot.tap(const Key('people.import.check'));
    await robot.settle();
    expect(find.textContaining('updates 2'), findsOneWidget);
    expect(find.byKey(const Key('people.import.missing.gJ')), findsOneWidget);
    await robot.tap(const Key('people.import.apply'));
    await robot.settle();
    await robot.tap(const Key('people.import.missing.gJ'));
    await robot.tap(const Key('people.import.cancelMissing'));
    expect(harness.calls.calls, contains(startsWith('cancelImportedGroups:')));
    final ila = await harness.firestore.doc('$e/participants/j1').get();
    expect(ila.data()!['status'], 'cancelled');
    expect(find.byKey(const Key('people.import.missing.gJ')), findsNothing);
    await robot.finish();
  });

  testWidgets('a job can be left and reopened for its report', (tester) async {
    final robot = await open(tester);
    await harness.firestore.doc('$e/imports/old').set({
      'fileName': 'old.csv',
      'status': 'done',
      'mode': 'apply',
      'createdAt': DateTime.utc(2026, 1, 1),
      'report': report(),
    });
    await robot.settle();
    await robot.tap(const Key('people.import.job.old'));
    expect(find.text('Imported: 2 added and 0 updated.'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('without a connection the upload fails, says so, and keeps the '
      'mapping to try again', (tester) async {
    final robot = await open(tester);
    picker.add('first.csv', first);
    await robot.tap(const Key('people.import.pick'));
    uploader.failNext = Exception('offline');
    await robot.tap(const Key('people.import.check'));
    expect(find.byKey(const Key('people.import.error')), findsOneWidget);
    expect(find.text('first.csv · 3 rows'), findsOneWidget);
    await robot.tap(const Key('people.import.check'));
    await robot.settle();
    expect(find.text('Row 3, Diet: missing'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('a file that is not CSV is explained', (tester) async {
    final robot = await open(tester);
    picker.add('broken.csv', 'Name\n"never closed');
    await robot.tap(const Key('people.import.pick'));
    expect(find.byKey(const Key('people.import.error')), findsOneWidget);
    expect(find.byKey(const Key('people.import.check')), findsNothing);
    await robot.finish();
  });

  testWidgets('without a name column, checking waits', (tester) async {
    final robot = await open(tester);
    picker.add('first.csv', first);
    await robot.tap(const Key('people.import.pick'));
    await robot.tap(const Key('people.import.map.2'));
    await tester.tap(find.text('Not imported').last);
    await robot.settle();
    expect(
      find.byKey(const Key('people.import.nameNotMapped')),
      findsOneWidget,
    );
    await robot.finish();
  });

  testWidgets('only participants.import opens it', (tester) async {
    final robot = await open(tester, as: 'lead');
    expect(find.byKey(const Key('roles.noAccess')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('leaving a mapped file unchecked asks first', (tester) async {
    final robot = await open(
      tester,
      location: '/dashboard/event/${RolesHarness.eventId}/people',
    );
    await robot.tap(const Key('people.roster.import'));
    await robot.finishTransition();
    picker.add('first.csv', first);
    await robot.tap(const Key('people.import.pick'));
    await tester.binding.handlePopRoute();
    await robot.settle();
    expect(find.byKey(const Key('roles.discard.confirm')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('fits a 375 px phone at 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(tester, size: const Size(375, 3000));
    picker.add('first.csv', first);
    await robot.tap(const Key('people.import.pick'));
    expect(tester.takeException(), isNull);
    await robot.tap(const Key('people.import.check'));
    await robot.settle();
    expect(tester.takeException(), isNull);
    await robot.finish();
  });
}
