import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';

/// Stands in for the `saveExpense` callable, writing what the server would.
/// Its validation is covered by `functions/test/events/saveExpense.test.ts`.
SaveExpenseCall fakeSaveExpenseCall(FirebaseFirestore firestore) =>
    (ExpenseModel expense) async {
      await firestore
          .collection('events')
          .doc(expense.eventId)
          .collection('expenses')
          .doc(expense.id)
          .set({
            'eventId': expense.eventId,
            'payerId': expense.payerId,
            'amount': expense.amount,
            'description': expense.description,
            'receiptPath': expense.receiptPath,
            'isDonation': expense.isDonation,
            'isPayment': false,
            'splits': [
              for (final split in expense.splits)
                {'userId': split.userId, 'amount': split.amount},
            ],
            'involvedUids': {
              expense.payerId,
              ...expense.splits.map((s) => s.userId),
            }.toList(),
          });
    };
