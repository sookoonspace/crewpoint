// Tests against the real app. Each name starts with its scenario ID. A failure
// here is a finding, so this suite lives outside test/ and CI's `flutter test`.
//
// Run: flutter test test_acceptance/
import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase;
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_csv_builder.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_pdf_builder.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/harness/dashboard_harness.dart';
import '../test/harness/fake_create_event.dart';
import 'seed.dart';

class _FakeChat implements IChatService {
  @override
  Stream<bool> readsFromCache(String eventId) => const Stream.empty();

  final ctrl = StreamController<List<ChatMessage>>.broadcast();
  @override
  Stream<List<ChatMessage>> messagesForEvent(String eventId) => ctrl.stream;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _event = EventModel(
  id: 'derod',
  title: 'Derod Gaam Convention 2027',
  creatorId: 'admin',
  memberIds: ['admin'],
  adminIds: ['admin'],
);

Iterable<File> _sources() sync* {
  for (final dir in ['lib', 'assets', 'functions/src', 'web']) {
    for (final e in Directory(dir).listSync(recursive: true)) {
      if (e is File &&
          RegExp(r'\.(dart|ts|json|md|html|arb|yaml)$').hasMatch(e.path)) {
        yield e;
      }
    }
  }
}

void main() {
  group('A-01 event setup', () {
    Future<Map<String, dynamic>> stored() async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fs = FakeFirebaseFirestore();
      final repo = EventRepository(
        eventsDao: EventsDao(db),
        firestore: fs,
        createEventCall: fakeCreateEventCall(fs),
      );
      await repo.createEvent(
        EventModel(
          id: _event.id,
          title: _event.title,
          creatorId: 'admin',
          memberIds: const ['admin'],
          adminIds: const ['admin'],
          startDate: DateTime.utc(2027, 7, 17),
          endDate: DateTime.utc(2027, 7, 20),
        ),
      );
      await repo.saveConfiguration(
        EventModel(
          id: _event.id,
          title: _event.title,
          creatorId: 'admin',
          timeZone: 'America/Chicago',
          venues: const [
            EventVenue(
              id: 'garland',
              name: 'Garland Hall',
              address: '1 Main St, Garland, TX',
            ),
          ],
        ),
      );
      return (await fs.doc('events/derod').get()).data()!;
    }

    test('A-01 stores title and dates', () async {
      final d = await stored();
      expect(d['title'], _event.title);
      expect(d['startDate'], isNotNull);
      expect(d['endDate'], isNotNull);
    });

    test('A-01 stores an event time zone and venue', () async {
      final d = await stored();
      expect(d['timeZone'], 'America/Chicago');
      final venue =
          (d['venues'] as List<dynamic>).single as Map<String, dynamic>;
      expect(venue['name'], 'Garland Hall');
      expect(venue['address'], '1 Main St, Garland, TX');
    });
  });

  group('A-03 Gujarati spelling', () {
    test('A-03 misspelling ડેરોડ appears nowhere in app or fixture', () {
      final hits = [
        for (final f in [
          ..._sources(),
          File('test_acceptance/fixtures/derod_convention_2027_v3.json'),
        ])
          if (f.readAsStringSync().contains('ડેરોડ')) f.path,
      ];
      expect(hits, isEmpty);
    });

    test('A-03 app contains Gujarati content spelled દેરોદ', () {
      final hits = [
        for (final f in _sources())
          if (f.readAsStringSync().contains('દેરોદ')) f.path,
      ];
      expect(hits, isNotEmpty, reason: 'No Gujarati strings exist in the app');
    });
  });

  test('J-09 app strings offer a Gujarati implementation', () {
    final src = File('lib/app/core/i18n/app_strings.dart').readAsStringSync();
    expect(src, isNotEmpty);
    expect(
      RegExp(r'class \w*Gujarati\w* |_Gu\w*Strings').hasMatch(src),
      isTrue,
      reason: 'AppStrings has only an English implementation',
    );
    // Keeps the import honest if the file moves.
    expect(AppStrings, isNotNull);
  });

  group('H-02 tasks', () {
    final now = DateTime(2027, 6, 15, 9);
    final tasks = [
      TaskModel(
        id: 't1',
        eventId: 'derod',
        title: 'Confirm caterer',
        assigneeId: 'food',
        dueDate: DateTime(2027, 6, 1),
      ),
      TaskModel(
        id: 't2',
        eventId: 'derod',
        title: 'Book DJ',
        assigneeId: 'program',
        dueDate: DateTime(2027, 7, 1),
      ),
      TaskModel(
        id: 't3',
        eventId: 'derod',
        title: 'Print badges',
        assigneeId: 'program',
        status: TaskStatus.done,
        dueDate: DateTime(2027, 6, 1),
      ),
    ];

    test('H-02 owner, due date, status, and overdue filter work', () {
      final overdue = applyTasksFilter(
        tasks,
        const TasksFilter(onlyOverdue: true),
        currentUserId: 'food',
        now: now,
      );
      expect(overdue.map((t) => t.id), ['t1']);
      expect(overdue.single.assigneeId, 'food');
    });

    test('H-02 tasks belong to a crew, filterable with overdue, and grouped', () {
      final crewTasks = [
        for (final t in tasks)
          t.copyWith(crewId: t.assigneeId == 'food' ? 'catering' : 'stage'),
      ];
      final cateringOverdue = applyTasksFilter(
        crewTasks,
        const TasksFilter(crewId: 'catering', onlyOverdue: true),
        currentUserId: 'food',
        now: now,
      );
      expect(cateringOverdue.map((t) => t.id), ['t1']);
      final groups = groupTasks(
        crewTasks,
        TasksGroupBy.crew,
        now: now,
        assigneeNames: const {},
        crewNames: const {'catering': 'Catering', 'stage': 'Stage'},
      );
      expect(groups.map((g) => g.label), ['Catering', 'Stage']);
    });
  });

  group('K-03 export', () {
    test('K-03 expense CSV contains every expense', () {
      final csv = buildExpenseCsv(
        event: _event,
        expenses: [
          for (var i = 0; i < 300; i++)
            ExpenseModel(
              id: 'exp$i',
              eventId: 'derod',
              payerId: 'admin',
              amount: 1.0 + i,
            ),
        ],
        memberNames: const {'admin': 'Admin'},
      );
      expect(RegExp(r'exp\d+').allMatches(csv).length, 300);
    });

    test('K-03 CSV neutralises formula injection', () {
      final csv = buildExpenseCsv(
        event: _event,
        expenses: const [
          ExpenseModel(
            id: 'e',
            eventId: 'derod',
            payerId: 'admin',
            amount: 1,
            description: '=HYPERLINK("http://evil.example","x")',
          ),
        ],
        memberNames: const {'admin': 'Admin'},
      );
      expect(
        csv,
        isNot(contains(RegExp(r'(^|,)"?=HYPERLINK', multiLine: true))),
      );
    });

    test('K-03 PDF report includes all expenses, not a capped subset', () {
      final many = [
        for (var i = 0; i < 400; i++)
          ExpenseModel(id: 'e$i', eventId: 'derod', payerId: 'a', amount: 1),
      ];
      expect(truncateExpensesForRender(many).rendered.length, 400);
    });
  });

  test('FND-07 every leading formula character is neutralised in exports', () {
    for (final lead in ['=', '+', '-', '@', '\t', '\r']) {
      final csv = buildExpenseCsv(
        event: _event,
        expenses: [
          ExpenseModel(
            id: 'e',
            eventId: 'derod',
            payerId: 'admin',
            amount: 1,
            description: '${lead}cmd',
          ),
        ],
        memberNames: const {'admin': 'Admin'},
      );
      expect(csv, contains("'${lead}cmd"));
    }
  });

  group('U-03 Gujarati rendering in PDF', () {
    Future<String> extract(String text) async {
      final bytes = await buildExpenseReport(
        event: _event,
        expenses: [
          ExpenseModel(
            id: 'e',
            eventId: 'derod',
            payerId: 'a',
            amount: 300,
            description: text,
          ),
        ],
        memberNames: const {'a': 'Admin'},
        ledger: BalanceLedger.calculate(
          expenses: const [],
          memberIds: const [],
        ),
      );
      final dir = Directory.systemTemp.createTempSync('pdf');
      addTearDown(() => dir.deleteSync(recursive: true));
      final pdf = File('${dir.path}/r.pdf')..writeAsBytesSync(bytes);
      final r = await Process.run('pdftotext', [pdf.path, '-']);
      return r.stdout as String;
    }

    test('U-03 control: Latin text survives to the PDF', () async {
      expect(await extract('Family fee Patel'), contains('Family fee Patel'));
    });

    test('U-03 Gujarati text survives to the PDF', () async {
      expect(await extract('દેરોદ'), contains('દેરોદ'));
    });
  });

  group('U-01 U-02 accessibility on the dashboard', () {
    Future<void> pumpDashboard(WidgetTester tester, double scale) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = DashboardJourneyHarness(
        currentUser: const AppUser(
          uid: 'savita',
          email: 'savita@example.com',
          displayName: 'Savita Mistry',
        ),
      );
      addTearDown(() async => harness.database.close());
      await harness.firestore.doc('events/derod').set({
        'title': 'Derod Gaam Convention 2027',
        'creatorId': 'admin',
        'adminIds': ['admin'],
        'memberIds': ['admin', 'savita'],
        'eventType': 'social',
        'status': 'active',
        'currency': 'USD',
      });
      await withClock(Clock.fixed(DateTime(2027, 6, 1, 9)), () async {
        await tester.pumpWidget(harness.buildApp());
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      });
    }

    testWidgets('U-01 dashboard has no overflow at 200% text', (tester) async {
      await pumpDashboard(tester, 2.0);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Derod Gaam'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('U-02 dashboard tap targets are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpDashboard(tester, 1.0);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });

  group('S-07 event screens at 400 people', () {
    test(
      'S-07 one new message with 5,000 in chat settles within 2 s',
      () async {
        final dir = Directory.systemTemp.createTempSync('s07');
        addTearDown(() => dir.deleteSync(recursive: true));
        final db = AppDatabase(NativeDatabase(File('${dir.path}/c.db')));
        addTearDown(db.close);
        final dao = ChatMessagesDao(db);
        final svc = _FakeChat();
        final repo = ChatRepository(chatService: svc, chatMessagesDao: dao);
        addTearDown(repo.dispose);
        var emits = 0;
        final sub = repo.watchMessages('derod').listen((_) => emits++);
        addTearDown(sub.cancel);

        List<ChatMessage> msgs(int n) => [
          for (var i = 0; i < n; i++)
            ChatMessage(
              id: 'm$i',
              eventId: 'derod',
              senderId: 'u${i % 400}',
              text: 'Message $i about tonight\'s program',
              timestamp: DateTime(2027).add(Duration(seconds: i)),
            ),
        ];

        Future<int> drain() async {
          final sw = Stopwatch()..start();
          var last = -1;
          var quiet = 0;
          var settledAt = 0;
          while (quiet < 8) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            if (emits != last) {
              last = emits;
              quiet = 0;
              settledAt = sw.elapsedMilliseconds;
            } else {
              quiet++;
            }
          }
          return settledAt;
        }

        svc.ctrl.add(msgs(5000));
        await drain();
        emits = 0;
        svc.ctrl.add(msgs(5001));
        final ms = await drain();
        // ignore: avoid_print
        print(
          'S-07 measured: ${ms}ms and $emits UI updates for one new message',
        );
        expect(ms, lessThan(2000));
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );

    test('S-07 ledger with 400 members and 2,000 expenses under 200 ms', () {
      final members = [for (var i = 0; i < 400; i++) 'u$i'];
      final expenses = [
        for (var i = 0; i < 2000; i++)
          ExpenseModel(
            id: 'e$i',
            eventId: 'derod',
            payerId: members[i % 400],
            amount: 100.0 + i,
            splits: [
              ExpenseSplit(userId: members[(i + 1) % 400], amount: 100.0 + i),
            ],
          ),
      ];
      final sw = Stopwatch()..start();
      final ledger = BalanceLedger.calculate(
        expenses: expenses,
        memberIds: members,
      );
      expect(sw.elapsedMilliseconds, lessThan(200));
      expect(ledger.netBalances.length, 400);
    });

    test('S-02 scale fixture cannot be imported: no import path exists', () {
      expect(scaleFamilies().length, 108);
      final hits = [
        for (final f in _sources())
          if (f.path.endsWith('.dart') &&
              RegExp(
                r'importRoster|CsvToList|csvDecode|Csv\(\)\.decode',
              ).hasMatch(f.readAsStringSync()))
            f.path,
      ];
      expect(hits, isNotEmpty);
    });
  });
}
