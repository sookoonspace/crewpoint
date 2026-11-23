import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// The longest an invite can last, matching `inviteExpiry.ts`: long enough
/// for a whole registration period (Req 56).
const maxInviteDays = 400;

/// The link an invite shares (Req 47). It opens `/join/:code` on this
/// flavor's web app, which a phone's camera opens from the QR code too.
String inviteLink(String code, {AppFlavor? flavor}) =>
    '${(flavor ?? AppFlavor.current).legalBaseUrl}/join/$code';

/// Expiries an organizer can pick (Req 56), besides a date of their own.
enum InviteExpiry { day, week, month, eventStart, eventEnd }

/// When [choice] ends, or null when it does not apply, such as an event
/// whose start has passed. Never later than [maxInviteDays] from [now].
DateTime? inviteExpiryFor(
  InviteExpiry choice,
  EventModel? event,
  DateTime now,
) {
  final DateTime? at = switch (choice) {
    InviteExpiry.day => now.add(const Duration(days: 1)),
    InviteExpiry.week => now.add(const Duration(days: 7)),
    InviteExpiry.month => now.add(const Duration(days: 30)),
    InviteExpiry.eventStart => _start(event),
    InviteExpiry.eventEnd => _end(event),
  };
  if (at == null || !at.isAfter(now.add(const Duration(minutes: 5)))) {
    return null;
  }
  return _clamp(at, now);
}

/// The choices that apply to [event] at [now].
List<InviteExpiry> inviteExpiryChoices(EventModel? event, DateTime now) => [
  for (final c in InviteExpiry.values)
    if (inviteExpiryFor(c, event, now) != null) c,
];

/// The end of a picked day, on this device's clock.
DateTime expiryOnDate(DateTime day, DateTime now) =>
    _clamp(DateTime(day.year, day.month, day.day, 23, 59), now);

DateTime _clamp(DateTime at, DateTime now) {
  final latest = now.add(const Duration(days: maxInviteDays));
  return at.isAfter(latest) ? latest : at;
}

DateTime? _start(EventModel? event) {
  final start = event?.startDate;
  if (event == null || start == null) return null;
  return event.dateOnly ? event.startOfDay(event.displayStart!) : start;
}

DateTime? _end(EventModel? event) {
  final end = event?.endDate;
  if (event == null || end == null) return null;
  if (!event.dateOnly) return end;
  // The whole last day counts.
  final last = event.displayEnd!;
  return event.startOfDay(DateTime(last.year, last.month, last.day + 1));
}

/// Whether a member invite link can be used (Spec #233 Req 15, #238), as
/// `inviteState` in `functions/src/events/inviteState.ts` decides it.
enum InviteLinkState { active, used, expired, off }

/// One of an event's member invite links (#238): its code, the role it
/// carries, its expiry, whether it works for one join only, how often it was
/// used, and whether it was turned off. `listInviteLinks` returns them.
class InviteLink {
  const InviteLink({
    required this.code,
    required this.roleId,
    this.expiresAt,
    this.singleUse = false,
    this.uses = 0,
    this.usedAt,
    this.turnedOffAt,
    this.createdAt,
  });

  /// A link as the server returns it, times in milliseconds.
  factory InviteLink.fromMap(Map<Object?, Object?> m) {
    DateTime? at(Object? v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return InviteLink(
      code: m['code'] as String? ?? '',
      roleId: m['roleId'] as String? ?? 'participant',
      expiresAt: at(m['expiresAt']),
      singleUse: m['singleUse'] == true,
      uses: (m['uses'] as num?)?.toInt() ?? 0,
      usedAt: at(m['usedAt']),
      turnedOffAt: at(m['turnedOffAt']),
      createdAt: at(m['createdAt']),
    );
  }

  final String code;
  final String roleId;

  /// Null means it never expires, as some invites from before #79 do.
  final DateTime? expiresAt;
  final bool singleUse;
  final int uses;

  /// When a single-use link was used.
  final DateTime? usedAt;
  final DateTime? turnedOffAt;
  final DateTime? createdAt;

  /// The state at [now]: turned off, then used, then expired.
  InviteLinkState stateAt(DateTime now) {
    if (turnedOffAt != null) return InviteLinkState.off;
    if (singleUse && usedAt != null) return InviteLinkState.used;
    final expires = expiresAt;
    if (expires != null && !expires.isAfter(now)) {
      return InviteLinkState.expired;
    }
    return InviteLinkState.active;
  }
}

/// [links] with the usable ones first, each part newest first, as the
/// server lists them.
List<InviteLink> usableFirst(List<InviteLink> links, DateTime now) => [
  for (final l in links)
    if (l.stateAt(now) == InviteLinkState.active) l,
  for (final l in links)
    if (l.stateAt(now) != InviteLinkState.active) l,
];
