import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/budget/presentation/budget_screen.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Event-scoped budget page. Reads the live `expenseListProvider(eventId)`
/// stream and routes mutations through `expenseRepositoryProvider`.
class EventBudgetPage extends ConsumerWidget {
  const EventBudgetPage({super.key, required this.event});

  final EventModel event;

  String _currencySymbol(String code) => switch (code) {
    'USD' || 'CAD' || 'AUD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    'JPY' => '¥',
    'INR' => '₹',
    _ => '\$',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final uid = auth is Authenticated ? auth.user.uid : null;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    final asyncExpenses = ref.watch(expenseListProvider(event.id));
    final repo = ref.watch(expenseRepositoryProvider);
    final imageService = ref.watch(imageServiceProvider);
    final symbol = _currencySymbol(event.currency);

    return asyncExpenses.when(
      data: (expenses) => BudgetScreen(
        expenses: expenses,
        memberIds: event.memberIds,
        currency: event.currency,
        onAddExpense: () => ExpenseModal.show(
          context: context,
          eventId: event.id,
          payerId: uid,
          memberIds: event.memberIds,
          currencySymbol: symbol,
          onPickReceipt: () => imageService.pickFromGallery(
            maxWidth: 1600,
            maxHeight: 1600,
            quality: 70,
          ),
          onSubmit: (expense, receipt) async {
            // Upload first (resilient: failure does not block save).
            String? receiptUrl;
            if (receipt != null) {
              receiptUrl = await repo.uploadReceipt(
                eventId: event.id,
                expenseId: expense.id,
                file: receipt,
              );
              if (receiptUrl == null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Receipt upload failed — saving expense without it',
                    ),
                    backgroundColor: AppColors.terracotta,
                  ),
                );
              }
            }
            final ok = await repo.createExpense(
              expense.copyWith(receiptPath: receiptUrl),
            );
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to add expense'),
                  backgroundColor: AppColors.terracotta,
                ),
              );
            }
          },
        ),
      ),
      loading: () => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Budget'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Budget'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
