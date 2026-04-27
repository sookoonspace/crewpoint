import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';

void main() {
  group('ExpenseModal.validateAmountInput', () {
    test('rejects empty', () {
      expect(ExpenseModal.validateAmountInput(''), isNotNull);
      expect(ExpenseModal.validateAmountInput(null), isNotNull);
      expect(ExpenseModal.validateAmountInput('   '), isNotNull);
    });

    test('rejects non-numeric', () {
      expect(ExpenseModal.validateAmountInput('abc'), isNotNull);
    });

    test('rejects below minAmount', () {
      expect(ExpenseModal.validateAmountInput('0.005'), isNotNull);
      expect(ExpenseModal.validateAmountInput('0'), isNotNull);
    });

    test('rejects above maxAmount', () {
      expect(ExpenseModal.validateAmountInput('20000000'), isNotNull);
    });

    test('accepts a normal amount', () {
      expect(ExpenseModal.validateAmountInput('25.50'), isNull);
      expect(ExpenseModal.validateAmountInput('1'), isNull);
    });
  });

  group('ExpenseModal.validateSplitSum', () {
    test('accepts splits that sum to total within \$0.01 tolerance', () {
      const splits = [
        ExpenseSplit(userId: 'a', amount: 33.33),
        ExpenseSplit(userId: 'b', amount: 33.33),
        ExpenseSplit(userId: 'c', amount: 33.34),
      ];
      expect(ExpenseModal.validateSplitSum(splits, 100.00), isNull);
    });

    test('rejects sum mismatch beyond tolerance', () {
      const splits = [
        ExpenseSplit(userId: 'a', amount: 50.00),
        ExpenseSplit(userId: 'b', amount: 49.00),
      ];
      expect(ExpenseModal.validateSplitSum(splits, 100.00), isNotNull);
    });
  });
}
