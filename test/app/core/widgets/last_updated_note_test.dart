import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/last_updated_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 74: mirrored screens say when they last updated while offline.
void main() {
  Future<void> pump(WidgetTester tester, MirrorSync? sync) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        mirrorSyncProvider.overrideWith((ref, _) => Stream.value(sync)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: LastUpdatedNote(mirrorKey: 'tasks/e1')),
      ),
    ),
  );

  testWidgets('says nothing while online', (tester) async {
    await pump(
      tester,
      MirrorSync(
        mirrorKey: 'tasks/e1',
        syncedAt: DateTime(2027, 7, 17, 10),
        fromCache: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('offline.note')), findsNothing);
  });

  testWidgets('offline, says when it last updated', (tester) async {
    await pump(
      tester,
      MirrorSync(
        mirrorKey: 'tasks/e1',
        syncedAt: DateTime(2027, 7, 17, 10, 42),
        fromCache: true,
      ),
    );
    await tester.pump();
    // intl may put a narrow space before AM.
    expect(
      find.textContaining(
        RegExp(r'^Offline\. Last updated Jul 17 10:42.AM\.$'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('offline before ever syncing, says it shows saved data', (
    tester,
  ) async {
    await pump(
      tester,
      const MirrorSync(mirrorKey: 'tasks/e1', fromCache: true),
    );
    await tester.pump();
    expect(find.textContaining('saved on this device'), findsOneWidget);
  });
}
