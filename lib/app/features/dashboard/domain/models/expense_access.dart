import 'package:flutter/foundation.dart';

/// The three expense access options (Req 38).
enum ExpenseAccessMode {
  /// Every member except Observers and Vendors, who are included only when
  /// [ExpenseAccess.includeNonContributors] is on.
  everyone,

  /// Members read only expenses they paid for or are part of.
  involved,

  /// The chosen roles and people read every expense.
  selected,
}

/// Who reads every expense in an event, from `settings.expenseAccess`.
/// Mirrors `functions/src/events/expenseAccess.ts`; the server decides, and
/// copies the result onto member documents as `expenses.readAll`. Whatever
/// the option, the payer and people in a split read that expense, and
/// `money.read` reads them all.
@immutable
class ExpenseAccess {
  const ExpenseAccess({
    required this.mode,
    this.includeNonContributors = false,
    this.roleIds = const [],
    this.uids = const [],
  });

  const ExpenseAccess.everyone({this.includeNonContributors = false})
    : mode = ExpenseAccessMode.everyone,
      roleIds = const [],
      uids = const [];

  /// A stored setting. Missing or malformed is Everyone, which is what every
  /// event before #72 allowed. Only what the option uses is kept.
  factory ExpenseAccess.fromMap(Object? raw) {
    final map = raw is Map ? raw : const <String, Object?>{};
    final mode = ExpenseAccessMode.values.firstWhere(
      (m) => m.name == map['mode'],
      orElse: () => ExpenseAccessMode.everyone,
    );
    List<String> strings(Object? value) => value is List
        ? {
            for (final v in value)
              if (v is String && v.isNotEmpty) v,
          }.toList()
        : const [];
    return ExpenseAccess(
      mode: mode,
      includeNonContributors:
          mode == ExpenseAccessMode.everyone &&
          map['includeNonContributors'] == true,
      roleIds: mode == ExpenseAccessMode.selected
          ? strings(map['roleIds'])
          : const [],
      uids: mode == ExpenseAccessMode.selected
          ? strings(map['uids'])
          : const [],
    );
  }

  final ExpenseAccessMode mode;
  final bool includeNonContributors;
  final List<String> roleIds;
  final List<String> uids;

  /// What `setExpenseAccess` takes.
  Map<String, Object> toMap() => {
    'mode': mode.name,
    'includeNonContributors':
        mode == ExpenseAccessMode.everyone && includeNonContributors,
    'roleIds': mode == ExpenseAccessMode.selected ? roleIds : const [],
    'uids': mode == ExpenseAccessMode.selected ? uids : const [],
  };

  /// Whether someone with [roles] reads every expense under this option.
  bool readsAll(String uid, List<String> roles) => switch (mode) {
    ExpenseAccessMode.everyone =>
      includeNonContributors ||
          roles.any((r) => r != 'observer' && r != 'vendor'),
    ExpenseAccessMode.involved => false,
    ExpenseAccessMode.selected =>
      uids.contains(uid) || roles.any(roleIds.contains),
  };

  ExpenseAccess copyWith({
    ExpenseAccessMode? mode,
    bool? includeNonContributors,
    List<String>? roleIds,
    List<String>? uids,
  }) => ExpenseAccess(
    mode: mode ?? this.mode,
    includeNonContributors:
        includeNonContributors ?? this.includeNonContributors,
    roleIds: roleIds ?? this.roleIds,
    uids: uids ?? this.uids,
  );

  @override
  bool operator ==(Object other) =>
      other is ExpenseAccess &&
      other.mode == mode &&
      other.includeNonContributors == includeNonContributors &&
      setEquals(other.roleIds.toSet(), roleIds.toSet()) &&
      setEquals(other.uids.toSet(), uids.toSet());

  @override
  int get hashCode => Object.hash(
    mode,
    includeNonContributors,
    Object.hashAllUnordered(roleIds),
    Object.hashAllUnordered(uids),
  );
}
