/// User notification preferences persisted at
/// `users/{uid}/private/profile.notificationPrefs`.
///
/// Categories ship one at a time as the CF roster grows. V1.1 exposed
/// only [pushEnabled] (master) + [urgentChat]; Phase 3a adds [taskUpdates];
/// Phase 3c.2 adds [payments]; Phase 3c.4 adds [eventUpdates] alongside
/// the new `onMemberJoined` CF. Defaults are opt-in (true) so a
/// brand-new account still receives every category before the user has
/// visited the settings screen.
///
/// **Phase 4 critical-alert opt-in withdrawn for V1/V2** — the Apple
/// `critical-alerts` entitlement requires explicit App Store review
/// approval, which we're deferring. Chat-urgent pushes always emit
/// `interruption-level: 'time-sensitive'` (no per-recipient opt-in)
/// and bypass quiet hours unconditionally while still obeying per-event
/// mute. Legacy `criticalOptIn` fields on existing Firestore docs are
/// silently ignored on read.
class NotificationPrefs {
  const NotificationPrefs({
    this.pushEnabled = true,
    this.urgentChat = true,
    this.taskUpdates = true,
    this.payments = true,
    this.eventUpdates = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.timezone,
    this.locale,
    this.dailyDigest = false,
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

  /// Quiet-hours window — minutes from midnight in the user's
  /// [timezone]. Values are `0`-`1439`; `start > end` means the window
  /// crosses midnight (e.g. 22:00-07:00 → `start = 1320`, `end = 420`).
  /// **All three of [quietHoursStart], [quietHoursEnd], [timezone] must
  /// be set for quiet hours to take effect** — the CF skips the check
  /// when any is null. `chat_urgent` bypasses quiet hours
  /// unconditionally (24/7 emergency channel); every other category
  /// honours the window.
  final int? quietHoursStart;

  /// See [quietHoursStart].
  final int? quietHoursEnd;

  /// IANA timezone identifier (e.g. `"America/New_York"`). Required for
  /// the CF to interpret [quietHoursStart] / [quietHoursEnd] against the
  /// recipient's wall clock. Server side uses Node's
  /// `Intl.DateTimeFormat({timeZone: ...})` — no third-party tz library
  /// dependency.
  final String? timezone;

  /// BCP-47 locale string (e.g. `"en"`, `"es-MX"`). Drives Phase 6
  /// notification-template selection on the server. Null means "use
  /// server default" (English). Server-side resolution lives in
  /// `functions/src/notifications/templates.ts` and falls back to the
  /// base language and then `en.json` when the exact locale is missing.
  final String? locale;

  /// Opt-in for the Phase 6.1 daily-digest push (morning summary of
  /// unread chat + pending tasks + open settlements). **Default false** —
  /// users must explicitly enable this to avoid surprise "good morning"
  /// pings. The CF runs every 60 minutes and fires when the recipient's
  /// local hour matches the digest send time (9:00 in their [timezone],
  /// reusing the Phase 5 IANA timezone field).
  final bool dailyDigest;

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
      quietHoursStart: _readMinuteOfDay(map['quietHoursStart']),
      quietHoursEnd: _readMinuteOfDay(map['quietHoursEnd']),
      timezone: _readNonEmptyString(map['timezone']),
      locale: _readNonEmptyString(map['locale']),
      dailyDigest: _readBool(map['dailyDigest'], fallback: false),
    );
  }

  Map<String, dynamic> toMap() => {
    'pushEnabled': pushEnabled,
    'urgentChat': urgentChat,
    'taskUpdates': taskUpdates,
    'payments': payments,
    'eventUpdates': eventUpdates,
    // Sparse — only persist quiet-hours fields when set; the CF only
    // checks the window when all three are present.
    if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
    if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
    if (timezone != null) 'timezone': timezone,
    // Sparse too — null means "server default (English)"; persisting
    // the absence keeps the doc small.
    if (locale != null) 'locale': locale,
    'dailyDigest': dailyDigest,
  };

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? urgentChat,
    bool? taskUpdates,
    bool? payments,
    bool? eventUpdates,
    int? quietHoursStart,
    int? quietHoursEnd,
    String? timezone,
    String? locale,
    bool? dailyDigest,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      urgentChat: urgentChat ?? this.urgentChat,
      taskUpdates: taskUpdates ?? this.taskUpdates,
      payments: payments ?? this.payments,
      eventUpdates: eventUpdates ?? this.eventUpdates,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      dailyDigest: dailyDigest ?? this.dailyDigest,
    );
  }

  /// Returns a copy with quiet hours explicitly cleared (all three
  /// nullable fields set to null). Use this instead of `copyWith` when
  /// the user disables quiet hours — `copyWith` can't transition a
  /// non-null value back to null because its parameters are nullable.
  NotificationPrefs withQuietHoursCleared() {
    return NotificationPrefs(
      pushEnabled: pushEnabled,
      urgentChat: urgentChat,
      taskUpdates: taskUpdates,
      payments: payments,
      eventUpdates: eventUpdates,
    );
  }

  static bool _readBool(Object? value, {required bool fallback}) {
    return value is bool ? value : fallback;
  }

  /// Accepts a `0`-`1439` int; returns null otherwise.
  static int? _readMinuteOfDay(Object? value) {
    if (value is int && value >= 0 && value <= 1439) return value;
    return null;
  }

  static String? _readNonEmptyString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}
