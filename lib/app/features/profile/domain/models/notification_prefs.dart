/// User notification preferences persisted at
/// `users/{uid}/private/profile.notificationPrefs`.
///
/// Categories ship one at a time as the CF roster grows. V1.1 exposed
/// only [pushEnabled] (master) + [urgentChat]; Phase 3a adds [taskUpdates];
/// Phase 3c.2 adds [payments]; Phase 3c.4 adds [eventUpdates] alongside
/// the new `onMemberJoined` CF. Future versions extend with `criticalOptIn`
/// and quiet-hours fields — add them here as scope grows. Defaults are
/// opt-in (true) so a brand-new account still receives every category
/// before the user has visited the settings screen.
class NotificationPrefs {
  const NotificationPrefs({
    this.pushEnabled = true,
    this.urgentChat = true,
    this.taskUpdates = true,
    this.payments = true,
    this.eventUpdates = true,
    this.criticalOptIn = false,
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

  /// Per-category opt-out for event-level updates (new members joining,
  /// future event-meta changes). CF reads this in `sendCategorizedPush`
  /// and skips the recipient when false.
  final bool eventUpdates;

  /// Opt-in for urgent chat alerts that bypass Do Not Disturb / Focus.
  /// **Default false** — Apple's `critical-alert` entitlement (iOS) and
  /// Android's `NOTIFICATION_POLICY_ACCESS_GRANTED` are explicit-consent
  /// privileges; defaulting them to true would be a hostile UX. The CF
  /// reads this in `sendCategorizedPush` for `category == 'chat_urgent'`
  /// to pick `apns.payload.aps.interruption-level` ('critical' vs
  /// 'time-sensitive'). On Android, the client-side `crewpoint_chat_urgent`
  /// channel toggles `setBypassDnd(true)` once the user grants policy
  /// access at the OS level.
  final bool criticalOptIn;

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
      eventUpdates: _readBool(map['eventUpdates'], fallback: true),
      criticalOptIn: _readBool(map['criticalOptIn'], fallback: false),
    );
  }

  Map<String, dynamic> toMap() => {
    'pushEnabled': pushEnabled,
    'urgentChat': urgentChat,
    'taskUpdates': taskUpdates,
    'payments': payments,
    'eventUpdates': eventUpdates,
    'criticalOptIn': criticalOptIn,
  };

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? urgentChat,
    bool? taskUpdates,
    bool? payments,
    bool? eventUpdates,
    bool? criticalOptIn,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      urgentChat: urgentChat ?? this.urgentChat,
      taskUpdates: taskUpdates ?? this.taskUpdates,
      payments: payments ?? this.payments,
      eventUpdates: eventUpdates ?? this.eventUpdates,
      criticalOptIn: criticalOptIn ?? this.criticalOptIn,
    );
  }

  static bool _readBool(Object? value, {required bool fallback}) {
    return value is bool ? value : fallback;
  }
}
