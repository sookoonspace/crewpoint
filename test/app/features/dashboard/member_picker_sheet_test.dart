import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/member_picker_sheet.dart';
import 'package:crewpoint_app/app/features/profile/data/firestore_user_repository.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

/// Fails the first [failures] page loads, as when offline.
class _FlakyRepo extends FirestoreUserRepository {
  _FlakyRepo({required super.firestore, this.failures = 0});

  int failures;
  int calls = 0;

  @override
  Future<MemberPage> fetchMemberPage(
    String eventId, {
    String search = '',
    MemberPage? after,
  }) {
    calls++;
    if (failures > 0) {
      failures--;
      return Future.error(StateError('offline'));
    }
    return super.fetchMemberPage(eventId, search: search, after: after);
  }
}

/// Req 43a: task assignment and expense splitting pick people a page at a
/// time, searching by name, so a large event never loads everyone.
void main() {
  late FakeFirebaseFirestore firestore;

  Future<void> seed(int count) async {
    final profiles = firestore
        .collection('events')
        .doc('e1')
        .collection('profiles');
    for (var i = 0; i < count; i++) {
      final name = 'Person ${i.toString().padLeft(3, '0')}';
      await profiles.doc('u$i').set({
        'uid': 'u$i',
        'displayName': name,
        'sortName': name.toLowerCase(),
        'inEvent': true,
      });
    }
    await profiles.doc('gil').set({
      'uid': 'gil',
      'displayName': 'Gil',
      'sortName': 'gil',
      'inEvent': false,
    });
  }

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<_FlakyRepo> open(
    WidgetTester tester, {
    bool multi = false,
    int failures = 0,
    Set<String> initial = const {},
    void Function(Object?)? onResult,
    Map<String, dynamic> labels = const {},
  }) async {
    final repo = _FlakyRepo(firestore: firestore, failures: failures);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('u1'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const Key('open'),
                onPressed: () async {
                  final words = LabelResolver(labels);
                  final result = multi
                      ? await MemberPickerSheet.pickMany(
                          context,
                          eventId: 'e1',
                          words: words,
                          initial: initial,
                        )
                      : await MemberPickerSheet.pickOne(
                          context,
                          eventId: 'e1',
                          words: words,
                        );
                  onResult?.call(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('pages in name order, without people who left', (tester) async {
    await seed(45);
    await open(tester);
    expect(find.text('Person 000'), findsOneWidget);
    expect(find.text('Person 001 (you)'), findsOneWidget);
    expect(find.text('Gil'), findsNothing);
    expect(find.text('Person 030'), findsNothing);

    final list = find.descendant(
      of: find.byKey(const Key('members.picker.list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('members.picker.more')),
      200,
      scrollable: list,
    );
    await tester.tap(find.byKey(const Key('members.picker.more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('members.picker.row.u44')),
      200,
      scrollable: list,
    );
    expect(find.byKey(const Key('members.picker.more')), findsNothing);
  });

  testWidgets('searches by the start of a name and picks one', (tester) async {
    await seed(45);
    AppUser? picked;
    await open(tester, onResult: (r) => picked = r as AppUser?);

    await tester.enterText(
      find.byKey(const Key('members.picker.search')),
      'person 04',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Person 000'), findsNothing);
    expect(find.text('Person 040'), findsOneWidget);

    await tester.tap(find.byKey(const Key('members.picker.row.u42')));
    await tester.pumpAndSettle();
    expect(picked?.uid, 'u42');
    expect(picked?.displayName, 'Person 042');
  });

  testWidgets('says when nobody matches, in the event\'s own word', (
    tester,
  ) async {
    await seed(3);
    await open(
      tester,
      labels: const {
        'member': {'one': 'Delegate', 'other': 'Delegates'},
      },
    );
    expect(find.text('Search delegates by name'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('members.picker.search')),
      'zz',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('members.picker.empty')), findsOneWidget);
    expect(
      find.text('No delegates have a name starting with that.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load can be tried again', (tester) async {
    await seed(3);
    final repo = await open(tester, failures: 1);
    expect(find.byKey(const Key('members.picker.error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('members.picker.retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('members.picker.error')), findsNothing);
    expect(find.text('Person 002'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('picks several, starting from who was chosen before', (
    tester,
  ) async {
    await seed(5);
    Set<String>? picked;
    await open(
      tester,
      multi: true,
      initial: {'u0', 'far-away'},
      onResult: (r) => picked = r as Set<String>?,
    );
    expect(find.text('Done (2)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('members.picker.row.u0')));
    await tester.tap(find.byKey(const Key('members.picker.row.u3')));
    await tester.tap(find.byKey(const Key('members.picker.row.u4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('members.picker.done')));
    await tester.pumpAndSettle();
    // Someone chosen but not on a loaded page stays chosen.
    expect(picked, {'far-away', 'u3', 'u4'});
  });

  testWidgets('closing without Done changes nothing', (tester) async {
    await seed(2);
    Object? result = 'unset';
    await open(tester, multi: true, onResult: (r) => result = r);
    await tester.tap(find.byKey(const Key('members.picker.row.u0')));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('fits a 375 px phone at 200% text, in dark mode', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await seed(3);
    await open(tester, multi: true);
    expect(tester.takeException(), isNull);
    for (final key in const [
      'members.picker.row.u0',
      'members.picker.done',
      'members.picker.search',
    ]) {
      expect(tester.getSize(find.byKey(Key(key))).height, greaterThan(47));
    }
  });
}
