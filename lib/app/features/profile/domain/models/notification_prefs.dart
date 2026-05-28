/// User notification preferences persisted at
/// `users/{uid}/private/profile.notificationPrefs`.
///
/// V1 surfaces only [pushEnabled] (master) + [urgentChat]. Subsequent
/// versions extend with `taskUpdates`, `eventUpdates`, `payments`,
/// `criticalOptIn`, and quiet-hours fields — add them here as the
/// feature scope grows. Defaults are opt-in (true) so a brand-new
/// account still receives urgent alerts before the user has visited
/// the settings screen.
class NotificationPrefs {
  const NotificationPrefs({this.pushEnabled = true, this.urgentChat = true});

  /// Master toggle — false means: do not request OS permission, do not
  /// persist a token, do not fan out any push to this user. Server-side
  /// enforcement lives in `functions/src/events/onUrgentMessageCreated.ts`.
  final bool pushEnabled;

  /// Per-category opt-out for high-priority chat (`🚨 Urgent`). Independent
  /// of [pushEnabled] so a user can keep the master on while muting only
  /// urgent threads — and so server-side CFs can check both flags.
  final bool urgentChat;

  /// Reads the Firestore subdoc fragment. Missing / wrong-typed fields
  /// fall through to the constructor defaults so a partial migration
  /// never throws at deserialisation.
  factory NotificationPrefs.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationPrefs();
    return NotificationPrefs(
      pushEnabled: _readBool(map['pushEnabled'], fallback: true),
      urgentChat: _readBool(map['urgentChat'], fallback: true),
    );
  }

  Map<String, dynamic> toMap() => {
    'pushEnabled': pushEnabled,
    'urgentChat': urgentChat,
  };

  NotificationPrefs copyWith({bool? pushEnabled, bool? urgentChat}) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      urgentChat: urgentChat ?? this.urgentChat,
    );
  }

  static bool _readBool(Object? value, {required bool fallback}) {
    return value is bool ? value : fallback;
  }
}
