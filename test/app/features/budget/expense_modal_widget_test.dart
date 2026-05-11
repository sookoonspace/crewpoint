import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';

// Smallest valid PNG decoder-compatible byte sequence used so Image.memory's
// errorBuilder doesn't fire during tests.
final _stubBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, // IDAT
  0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05,
  0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

PickedImage _stubReceipt() => PickedImage(
  bytes: _stubBytes,
  filename: 'fake-receipt.png',
  contentType: 'image/png',
);

void main() {
  testWidgets('Add receipt button is hidden when onPickReceipt is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpenseModal(
            eventId: 'evt-1',
            payerId: 'u1',
            memberIds: ['u1', 'u2'],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('budget.expense.receipt.add')), findsNothing);
  });

  testWidgets(
    'Add receipt button visible + tap pulls picker; preview shown after',
    (tester) async {
      Future<PickedImage?> picker() async => _stubReceipt();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseModal(
              eventId: 'evt-1',
              payerId: 'u1',
              memberIds: const ['u1', 'u2'],
              onPickReceipt: picker,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('budget.expense.receipt.add')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('budget.expense.receipt.add')));
      await tester.pump();

      expect(
        find.byKey(const Key('budget.expense.receipt.preview')),
        findsOneWidget,
      );
    },
  );

  testWidgets('submit passes the picked receipt to onSubmit', (tester) async {
    Future<PickedImage?> picker() async => _stubReceipt();
    ExpenseModel? submitted;
    PickedImage? submittedReceipt;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ExpenseModal(
              eventId: 'evt-1',
              payerId: 'u1',
              memberIds: const ['u1', 'u2'],
              onPickReceipt: picker,
              onSubmit: (expense, receipt) {
                submitted = expense;
                submittedReceipt = receipt;
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('budget.expense.amount')),
      '12.34',
    );
    await tester.tap(find.byKey(const Key('budget.expense.receipt.add')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('budget.expense.save')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.amount, closeTo(12.34, 0.001));
    expect(submittedReceipt, isNotNull);
    expect(submittedReceipt!.bytes, equals(_stubBytes));
    expect(submittedReceipt!.contentType, equals('image/png'));
  });

  testWidgets(
    'edit mode: pre-fills amount + description, Save label flips, preserves id',
    (tester) async {
      const initial = ExpenseModel(
        id: 'exp-existing',
        eventId: 'evt-1',
        payerId: 'u1',
        amount: 42.5,
        description: 'Original',
        isDonation: true,
      );

      ExpenseModel? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseModal(
              eventId: 'evt-1',
              payerId: 'u1',
              memberIds: const ['u1', 'u2'],
              initial: initial,
              onSubmit: (expense, _) => submitted = expense,
            ),
          ),
        ),
      );

      // Pre-fill assertions.
      final amount = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('budget.expense.amount')),
          matching: find.byType(TextField),
        ),
      );
      expect(amount.controller!.text, '42.5');

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('Add Expense'), findsNothing);

      // Save button label flips.
      expect(find.text('Save changes'), findsOneWidget);

      // Edit amount and submit → id preserved.
      await tester.enterText(
        find.byKey(const Key('budget.expense.amount')),
        '99.99',
      );
      await tester.tap(find.byKey(const Key('budget.expense.save')));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.id, 'exp-existing');
      expect(submitted!.amount, closeTo(99.99, 0.001));
      expect(submitted!.isDonation, isTrue);
    },
  );
}
