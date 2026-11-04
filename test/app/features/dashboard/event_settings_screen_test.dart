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

  group('saving', () {
    testWidgets('saves every field and goes back', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(_key('timeZone')), 'America/Chicago');
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
        ('timeZone', 'not a zone'),
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

  group('capacity (Req 18b)', () {
    testWidgets('shows the count against capacity', (tester) async {
      await pump(tester);
      expect(find.text('3 of 500 attending'), findsOneWidget);
    });

    testWidgets('shows the count alone when no capacity is set', (
      tester,
    ) async {
      await pump(tester, event: _event.copyWith(clearCapacity: true));
      expect(find.text('3 attending'), findsOneWidget);
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
