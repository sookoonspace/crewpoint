/// User notification preferences persisted at
/// `users/{uid}/private/profile.notificationPrefs`.
///
/// Categories ship one at a time as the CF roster grows. V1.1 exposed
/// only [pushEnabled] (master) + [urgentChat]; Phase 3a adds [taskUpdates];
/// Phase 3c.2 adds [payments] alongside the new `onExpenseCreated` CF.
/// Future versions extend with `eventUpdates`, `criticalOptIn`, and
/// quiet-hours fields — add them here as scope grows. Defaults are opt-in
/// (true) so a brand-new account still receives every category before the
/// user has visited the settings screen.
class NotificationPrefs {
  const NotificationPrefs({
    this.pushEnabled = true,
    this.urgentChat = true,
    this.taskUpdates = true,
    this.payments = true,
  });

  /// Master toggle — false means: do not request OS permission, do not
  /// persist a token, do not fan out any push to this user. Server-side
  /// enforcement lives in `functions/src/notifications/sendPush.ts`.
  final bool pushEnabled;

  /// Per-category opt-out for high-priority chat (`🚨 Urgent`). Independent
  /// of [pushEnabled] so a user can keep the master on while muting only
  /// urgent threads — and so server-side CFs can check both flags.
  final bool urgentChat;

  /// Per-category opt-out for task assignments + (future) due-date
  /// reminders. CF reads this in `sendCategorizedPush` and skips the
  /// recipient when false.
  final bool taskUpdates;

  /// Per-category opt-out for payments: new expenses + settlement
  /// disputes. CF reads this in `sendCategorizedPush` and skips the
  /// recipient when false.
  final bool payments;

  /// Reads the Firestore subdoc fragment. Missing / wrong-typed fields
  /// fall through to the constructor defaults so a partial migration
  /// never throws at deserialisation.
  factory NotificationPrefs.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationPrefs();
    return NotificationPrefs(
      pushEnabled: _readBool(map['pushEnabled'], fallback: true),
      urgentChat: _readBool(map['urgentChat'], fallback: true),
      taskUpdates: _readBool(map['taskUpdates'], fallback: true),
      payments: _readBool(map['payments'], fallback: true),
    );
  }

  Map<String, dynamic> toMap() => {
    'pushEnabled': pushEnabled,
    'urgentChat': urgentChat,
    'taskUpdates': taskUpdates,
    'payments': payments,
  };

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? urgentChat,
    bool? taskUpdates,
    bool? payments,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      urgentChat: urgentChat ?? this.urgentChat,
      taskUpdates: taskUpdates ?? this.taskUpdates,
      payments: payments ?? this.payments,
    );
  }

  static bool _readBool(Object? value, {required bool fallback}) {
    return value is bool ? value : fallback;
  }
}
