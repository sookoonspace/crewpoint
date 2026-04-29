import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Pure RFC-4180 CSV builder for an event's expense list.
///
/// Returns a single string suitable for download. No Flutter / Firebase
/// imports beyond domain models so this is testable without a binding.
String buildExpenseCsv({
  required EventModel event,
  required List<ExpenseModel> expenses,
  required Map<String, String> memberNames,
}) {
  const header = [
    'id',
    'createdAt',
    'payerId',
    'payerName',
    'amount',
    'currency',
    'isDonation',
    'isPayment',
    'description',
    'receiptPath',
    'splits',
  ];

  final rows = <List<String>>[
    header,
    for (final e in expenses) _row(e, event, memberNames),
  ];

  const converter = ListToCsvConverter(eol: '\n');
  return converter.convert(rows);
}

List<String> _row(
  ExpenseModel e,
  EventModel event,
  Map<String, String> memberNames,
) {
  return [
    e.id,
    e.createdAt?.toIso8601String() ?? '',
    e.payerId,
    memberNames[e.payerId] ?? '',
    e.amount.toString(),
    event.currency,
    e.isDonation.toString(),
    e.isPayment.toString(),
    e.description ?? '',
    e.receiptPath ?? '',
    jsonEncode([
      for (final s in e.splits) {'userId': s.userId, 'amount': s.amount},
    ]),
  ];
}
