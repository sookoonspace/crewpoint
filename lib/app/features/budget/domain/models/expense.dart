/// Domain model for an expense.
class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.eventId,
    required this.payerId,
    required this.amount,
    this.description,
    this.receiptPath,
    this.isDonation = false,
    this.splits = const [],
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String payerId;
  final double amount;
  final String? description;
  final String? receiptPath;
  final bool isDonation;
  final List<ExpenseSplit> splits;
  final DateTime? createdAt;

  /// Calculates equal splits among members.
  /// If [isDonation], the payer is excluded from the split.
  static List<ExpenseSplit> calculateSplits({
    required double amount,
    required String payerId,
    required List<String> memberIds,
    required bool isDonation,
  }) {
    final splittingMembers = isDonation
        ? memberIds.where((id) => id != payerId).toList()
        : memberIds;

    if (splittingMembers.isEmpty) return [];

    final splitAmount = amount / splittingMembers.length;

    return splittingMembers
        .map((id) => ExpenseSplit(userId: id, amount: splitAmount))
        .toList();
  }
}

class ExpenseSplit {
  const ExpenseSplit({required this.userId, required this.amount});

  final String userId;
  final double amount;
}
