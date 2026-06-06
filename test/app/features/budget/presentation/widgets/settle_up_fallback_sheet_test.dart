import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/settle_up_fallback_sheet.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

const _event = EventModel(
  id: 'evt-1',
  title: 'Tahoe Trip',
  creatorId: 'me',
  memberIds: ['me', 'alex'],
  currency: 'USD',
);

const _debt = DebtRow(
  counterpartyUid: 'alex',
  counterpartyName: 'Alex',
  event: _event,
  amount: 45,
  currency: 'USD',
);

/// Pumps a tiny app whose home button opens the sheet — gives us a real
/// BuildContext with Material + Navigator + a GoRouter for the
/// "Mark paid" link target.
Future<void> _pumpAndOpenSheet(
  WidgetTester tester, {
  required DebtRow row,
  required AppUser? counterparty,
  void Function(String location)? onNavigatePushed,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _OpenSheetHost()),
      GoRoute(
        path: '/dashboard/event/:eventId/budget',
        builder: (ctx, state) {
          onNavigatePushed?.call(state.uri.toString());
          return const Scaffold(body: Text('event budget'));
        },
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();

  final hostState = tester.state<_OpenSheetHostState>(
    find.byType(_OpenSheetHost),
  );
  hostState.openSheet(row: row, counterparty: counterparty);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _OpenSheetHost extends StatefulWidget {
  const _OpenSheetHost();
  @override
  State<_OpenSheetHost> createState() => _OpenSheetHostState();
}

class _OpenSheetHostState extends State<_OpenSheetHost> {
  /// Returns immediately — the modal's own Future is never awaited so
  /// the caller doesn't hang waiting for the sheet to dismiss.
  void openSheet({required DebtRow row, required AppUser? counterparty}) {
    unawaited(SettleUpFallbackSheet.show(context, row, counterparty));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

void main() {
  setUp(() {
    // Capture Clipboard.setData calls without hitting the real platform.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            _clipboardCalls.add(call.arguments as Map);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    _clipboardCalls.clear();
  });

  testWidgets('renders recipient name + amount in event currency', (
    tester,
  ) async {
    await _pumpAndOpenSheet(
      tester,
      row: _debt,
      counterparty: const AppUser(
        uid: 'alex',
        email: 'alex@example.com',
        displayName: 'Alex Cole',
      ),
    );

    expect(
      find.byKey(const Key('budget.settleUp.fallback.sheet')),
      findsOneWidget,
    );
    expect(find.text('Pay Alex Cole'), findsOneWidget);
    expect(find.textContaining('\$45'), findsOneWidget);
  });

  testWidgets('Copy Amount writes the raw amount string to the clipboard', (
    tester,
  ) async {
    await _pumpAndOpenSheet(
      tester,
      row: _debt,
      counterparty: const AppUser(uid: 'alex', email: 'a@x.com'),
    );

    await tester.tap(
      find.byKey(const Key('budget.settleUp.fallback.copyAmount')),
    );
    await tester.pump();

    expect(_clipboardCalls, hasLength(1));
    expect(_clipboardCalls.single['text'], '45.00');
  });

  testWidgets(
    'Copy Handle button only shows when counterparty has a paymentHandle',
    (tester) async {
      await _pumpAndOpenSheet(
        tester,
        row: _debt,
        counterparty: const AppUser(
          uid: 'alex',
          email: 'a@x.com',
          paymentHandle: 'alex_handle',
        ),
      );

      expect(
        find.byKey(const Key('budget.settleUp.fallback.copyHandle')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('budget.settleUp.fallback.copyHandle')),
      );
      await tester.pump();
      expect(_clipboardCalls.last['text'], 'alex_handle');
    },
  );

  testWidgets('no counterparty → no Copy Handle button', (tester) async {
    await _pumpAndOpenSheet(tester, row: _debt, counterparty: null);

    expect(
      find.byKey(const Key('budget.settleUp.fallback.copyHandle')),
      findsNothing,
    );
  });

  testWidgets(
    '"Mark paid" link pops the sheet AND pushes /dashboard/event/<id>/budget',
    (tester) async {
      String? pushedLocation;
      await _pumpAndOpenSheet(
        tester,
        row: _debt,
        counterparty: null,
        onNavigatePushed: (loc) => pushedLocation = loc,
      );

      await tester.tap(
        find.byKey(const Key('budget.settleUp.fallback.markPaid')),
      );
      await tester.pumpAndSettle();

      expect(pushedLocation, '/dashboard/event/evt-1/budget');
      // Sheet popped.
      expect(
        find.byKey(const Key('budget.settleUp.fallback.sheet')),
        findsNothing,
      );
    },
  );
}

final List<Map<Object?, Object?>> _clipboardCalls = [];
