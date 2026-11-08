import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_settings_screen.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../harness/fake_create_event.dart';

const _event = EventModel(
  id: 'evt',
  title: 'Convention',
  creatorId: 'owner',
  adminIds: ['owner', 'admin'],
  memberIds: ['owner', 'admin', 'member'],
  capacity: 500,
);

Key _key(String name) => Key('events.settings.$name');

void main() {
  late AppDatabase database;
  late FakeFirebaseFirestore firestore;
  late List<String> currencyCalls;
  Object? currencyError;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    currencyCalls = [];
    currencyError = null;
    await firestore.doc('events/evt').set({
      'title': 'Convention',
      'creatorId': 'owner',
      'memberIds': ['owner', 'admin', 'member'],
    });
  });
  tearDown(() => database.close());

  Future<void> pump(
    WidgetTester tester, {
    String? uid = 'owner',
    List<ExpenseModel> expenses = const [],
    Stream<List<ExpenseModel>>? expenseStream,
    EventModel event = _event,
    ThemeData? theme,
    Size size = const Size(1200, 2400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(uid),
          firestoreProvider.overrideWithValue(firestore),
          expenseListProvider(
            event.id,
          ).overrideWith((_) => expenseStream ?? Stream.value(expenses)),
          eventRepositoryProvider.overrideWithValue(
            EventRepository(
              eventsDao: EventsDao(database),
              firestore: firestore,
              createEventCall: fakeCreateEventCall(firestore),
            ),
          ),
          changeEventCurrencyCallProvider.overrideWithValue((
            _,
            currency,
          ) async {
            currencyCalls.add(currency);
            if (currencyError != null) throw currencyError!;
          }),
        ],
        child: MaterialApp.router(
          theme: theme,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/dashboard/event/:eventId/settings/expenses',
                builder: (_, _) => const Text('expense access screen'),
              ),
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => context.push('/settings'),
                    child: const Text('open'),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => EventSettingsScreen(event: event),
                  ),
                ],
              ),
            ],
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(_key('save')));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> stored() async =>
      (await firestore.doc('events/evt').get()).data()!;

  group('access', () {
    testWidgets('a plain member sees no form', (tester) async {
      await pump(tester, uid: 'member');
      expect(find.byKey(_key('noAccess')), findsOneWidget);
      expect(find.byKey(_key('save')), findsNothing);
      await tester.tap(find.byKey(_key('back')));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('an admin sees the form', (tester) async {
      await pump(tester, uid: 'admin');
      expect(find.byKey(_key('save')), findsOneWidget);
    });
  });

  group('capacity (Req 18b, PA-05)', () {
    testWidgets('counts everyone attending, with or without an account', (
      tester,
    ) async {
      for (final (id, status) in [
        ('a', 'active'),
        ('b', 'active'),
        ('c', 'active'),
        ('d', 'active'),
        ('gone', 'cancelled'),
      ]) {
        await firestore.doc('events/evt/participants/$id').set({
          'name': id,
          'sortName': id,
          'isChild': false,
          'status': status,
        });
      }
      await pump(tester);
      await tester.pumpAndSettle();
      // Three members have accounts; four people are attending.
      expect(find.text('4 of 500 attending'), findsOneWidget);
    });

    testWidgets('shows the count alone when no capacity is set', (
      tester,
    ) async {
      await firestore.doc('events/evt/participants/a').set({
        'name': 'a',
        'sortName': 'a',
        'isChild': false,
        'status': 'active',
      });
      await pump(tester, event: _event.copyWith(clearCapacity: true));
      await tester.pumpAndSettle();
      expect(find.text('1 attending'), findsOneWidget);
    });
  });

  group('who can see expenses (Req 38)', () {
    testWidgets('shows the current option and opens its screen', (
      tester,
    ) async {
      await pump(
        tester,
        event: const EventModel(
          id: 'evt',
          title: 'Convention',
          creatorId: 'owner',
          adminIds: ['owner', 'admin'],
          memberIds: ['owner', 'admin', 'member'],
          settings: {
            'expenseAccess': {'mode': 'involved'},
          },
        ),
      );
      final entry = find.byKey(_key('expenseAccess'));
      await tester.ensureVisible(entry);
      expect(
        find.descendant(of: entry, matching: find.text('Only people involved')),
        findsOneWidget,
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('expense access screen'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('saves every field and goes back', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(_key('timeZone')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_key('timeZone.search')), 'chicago');
      await tester.pump();
      await tester.tap(find.byKey(_key('timeZone.America/Chicago')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key('venue.add')));
      await tester.pump();
      await tester.enterText(find.byKey(_key('venue.0.name')), 'Garland Hall');
      await tester.enterText(find.byKey(_key('venue.0.address')), '1 Main St');
      await tester.enterText(find.byKey(_key('languages')), 'en, gu');
      await tester.enterText(find.byKey(_key('capacity')), '600');
      await tester.enterText(find.byKey(_key('memberLimit')), '100');
      await save(tester);

      final data = await stored();
      expect(data['timeZone'], 'America/Chicago');
      final venue =
          (data['venues'] as List<dynamic>).single as Map<String, dynamic>;
      expect(venue['name'], 'Garland Hall');
      expect(venue['address'], '1 Main St');
      expect(data['languages'], ['en', 'gu']);
      expect(data['capacity'], 600);
      expect(data['memberLimit'], 100);
      expect(currencyCalls, isEmpty);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Settings saved'), findsOneWidget);
    });

    testWidgets('emptying capacity and the limit clears them', (tester) async {
      await pump(tester, event: _event.copyWith(memberLimit: 50));
      await tester.enterText(find.byKey(_key('capacity')), '');
      await tester.enterText(find.byKey(_key('memberLimit')), '');
      await save(tester);
      final data = await stored();
      expect(data['capacity'], isNull);
      expect(data['memberLimit'], isNull);
    });

    testWidgets('a removed venue is gone after saving', (tester) async {
      await pump(
        tester,
        event: _event.copyWith(
          venues: const [EventVenue(id: 'v', name: 'Hall')],
        ),
      );
      await tester.tap(find.byKey(_key('venue.0.remove')));
      await tester.pump();
      expect(find.byKey(_key('venuesEmpty')), findsOneWidget);
      await save(tester);
      expect((await stored())['venues'], isEmpty);
    });

    testWidgets('a failed save keeps the form and offers retry', (
      tester,
    ) async {
      await firestore.doc('events/evt').delete();
      await pump(tester);
      await tester.enterText(find.byKey(_key('capacity')), '600');
      await save(tester);
      expect(find.byKey(_key('error')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(_key('capacity')))
            .controller!
            .text,
        '600',
      );

      await firestore.doc('events/evt').set({'title': 'Back'});
      await save(tester);
      expect((await stored())['capacity'], 600);
    });
  });

  group('validation', () {
    testWidgets('bad values stop the save and nothing is written', (
      tester,
    ) async {
      for (final (field, value) in [
        ('capacity', '0'),
        ('capacity', 'many'),
        ('memberLimit', '-1'),
        ('languages', ''),
        ('languages', 'english language'),
      ]) {
        await pump(tester);
        await tester.enterText(find.byKey(_key(field)), value);
        await tester.tap(find.byKey(_key('save')));
        await tester.pump();
        expect(
          find.byKey(_key('save')),
          findsOneWidget,
          reason: '$field=$value',
        );
        expect((await stored()).containsKey('timeZone'), isFalse);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a venue needs a name', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(_key('venue.add')));
      await tester.pump();
      await tester.tap(find.byKey(_key('save')));
      await tester.pump();
      expect(find.text('Enter a name, or remove this venue'), findsOneWidget);
    });
  });

  group('currency (Req 17)', () {
    Future<void> choose(WidgetTester tester, String code) async {
      await tester.tap(find.byKey(_key('currency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(code).last);
      await tester.pumpAndSettle();
    }

    testWidgets('changes through the callable', (tester) async {
      await pump(tester);
      await choose(tester, 'EUR');
      await save(tester);
      expect(currencyCalls, ['EUR']);
    });

    testWidgets('is disabled once the event has an expense', (tester) async {
      await pump(
        tester,
        expenses: const [
          ExpenseModel(id: 'x', eventId: 'evt', payerId: 'owner', amount: 1),
        ],
      );
      final field = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(_key('currency')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(field.onChanged, isNull);
      expect(find.textContaining('currency cannot change'), findsOneWidget);
    });

    testWidgets('is disabled until the expenses are known', (tester) async {
      await pump(tester, expenseStream: const Stream.empty());
      final field = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(_key('currency')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(field.onChanged, isNull);
    });

    testWidgets('a server refusal saves nothing and explains', (tester) async {
      currencyError = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'x',
      );
      await pump(tester);
      await tester.enterText(find.byKey(_key('capacity')), '600');
      await choose(tester, 'EUR');
      await save(tester);
      expect(find.textContaining('currency cannot change'), findsWidgets);
      expect((await stored()).containsKey('capacity'), isFalse);
      expect(find.byKey(_key('save')), findsOneWidget);
    });

    testWidgets('offline says it needs a connection', (tester) async {
      currencyError = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'x',
      );
      await pump(tester);
      await choose(tester, 'EUR');
      await save(tester);
      expect(find.textContaining('needs a connection'), findsOneWidget);
    });
  });

  group('status (Req 19)', () {
    Future<void> choose(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(_key('status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('an organizer changes the status by hand', (tester) async {
      await pump(tester);
      await choose(tester, 'Live');
      await save(tester);
      final data = await stored();
      expect(data['status'], 'live');
      expect(data['statusSetAt'], isNotNull);
    });

    testWidgets('an event with members cannot pick draft', (tester) async {
      await pump(tester);
      expect(find.textContaining('cannot go back to draft'), findsOneWidget);
      await tester.tap(find.byKey(_key('status')));
      await tester.pumpAndSettle();
      final draft = tester.widget<DropdownMenuItem<EventStatus>>(
        find.ancestor(
          of: find.text('Draft').last,
          matching: find.byType(DropdownMenuItem<EventStatus>),
        ),
      );
      expect(draft.enabled, isFalse);
    });

    testWidgets('an organizer-only event can go back to draft', (tester) async {
      await pump(
        tester,
        event: const EventModel(
          id: 'evt',
          title: 'Convention',
          creatorId: 'owner',
          memberIds: ['owner'],
        ),
      );
      await choose(tester, 'Draft');
      await save(tester);
      expect((await stored())['status'], 'draft');
    });

    testWidgets('an archived event can only be restored', (tester) async {
      await pump(tester, event: _event.copyWith(status: EventStatus.archived));
      expect(find.byKey(_key('archivedNotice')), findsOneWidget);
      expect(find.byKey(_key('venue.add')), findsNothing);
      expect(
        tester.widget<TextFormField>(find.byKey(_key('capacity'))).enabled,
        isFalse,
      );
      await choose(tester, 'Published');
      await save(tester);
      final data = await stored();
      expect(data['status'], 'published');
      expect(data.containsKey('timeZone'), isFalse);
    });
  });

  group('labels (Req 20)', () {
    Future<void> openLabels(WidgetTester tester) async {
      await tester.tap(find.byKey(_key('labels')));
      await tester.pumpAndSettle();
    }

    testWidgets('renaming a concept saves only what was typed', (tester) async {
      await pump(tester);
      await openLabels(tester);
      await tester.enterText(find.byKey(_key('label.group.one')), 'Team');
      await tester.enterText(find.byKey(_key('label.group.other')), 'Teams');
      await tester.ensureVisible(find.byKey(_key('save')));
      await save(tester);
      expect((await stored())['labels'], {
        'group': {'one': 'Team', 'other': 'Teams'},
      });
    });

    testWidgets('emptying a box goes back to the default', (tester) async {
      await pump(
        tester,
        event: _event.copyWith(
          labels: const {
            'group': {'one': 'Team', 'other': 'Teams'},
          },
        ),
      );
      await openLabels(tester);
      expect(find.text('Team'), findsOneWidget);
      await tester.enterText(find.byKey(_key('label.group.one')), '');
      await tester.enterText(find.byKey(_key('label.group.other')), '');
      await tester.ensureVisible(find.byKey(_key('save')));
      await save(tester);
      expect((await stored())['labels'], isEmpty);
    });

    testWidgets('leaving without saving asks first', (tester) async {
      await pump(tester);
      await openLabels(tester);
      await tester.enterText(find.byKey(_key('label.group.one')), 'Team');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('modules (Req 22)', () {
    testWidgets('an organizer turns one off and on', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(_key('module.budget')));
      await tester.pump();
      await save(tester);
      expect((await stored())['modules'], {
        'tasks': true,
        'budget': false,
        'chat': true,
      });
    });

    testWidgets('an event that turned one off shows it off', (tester) async {
      await pump(
        tester,
        event: _event.copyWith(modules: const {'tasks': false}),
      );
      expect(
        tester.widget<SwitchListTile>(find.byKey(_key('module.tasks'))).value,
        isFalse,
      );
      expect(
        tester.widget<SwitchListTile>(find.byKey(_key('module.chat'))).value,
        isTrue,
      );
    });

    testWidgets('changing one counts as unsaved', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(_key('module.chat')));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('leaving with unsaved changes', () {
    Future<void> back(WidgetTester tester) async {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    testWidgets('leaves at once when nothing changed', (tester) async {
      await pump(tester);
      await back(tester);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('asks first, and keep editing keeps the data', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(_key('capacity')), '600');
      await tester.pump();
      await back(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.byKey(_key('keepEditing')));
      await tester.pumpAndSettle();
      expect(find.text('600'), findsOneWidget);
    });

    testWidgets('discard leaves without saving', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(_key('capacity')), '600');
      await tester.pump();
      await back(tester);
      await tester.tap(find.byKey(_key('discard')));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect((await stored()).containsKey('capacity'), isFalse);
    });
  });

  group('layout', () {
    for (final (name, theme) in [
      ('light', AppTheme.light()),
      ('dark', AppTheme.dark()),
    ]) {
      testWidgets('fits 375 px at 200% text in $name mode', (tester) async {
        await pump(
          tester,
          theme: theme,
          size: const Size(375, 800),
          textScale: 2,
          event: _event.copyWith(
            venues: const [EventVenue(id: 'v', name: 'Hall')],
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(_key('save')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('targets are at least 48 px and labelled', (tester) async {
      await pump(
        tester,
        event: _event.copyWith(
          venues: const [EventVenue(id: 'v', name: 'Hall')],
        ),
      );
      final handle = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
