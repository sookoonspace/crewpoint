import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the event's Budget list was scrolled to, so choosing an expense,
/// which builds the list again beside it (Spec #186 Req 23), keeps the
/// place. Not state: scrolling never rebuilds anything.
class BudgetListController extends Notifier<void> {
  BudgetListController(this.eventId);

  final String eventId;
  double scrollOffset = 0;

  @override
  void build() {}
}

/// Kept while any Budget list for the event shows.
final budgetListProvider = NotifierProvider.autoDispose
    .family<BudgetListController, void, String>(BudgetListController.new);
