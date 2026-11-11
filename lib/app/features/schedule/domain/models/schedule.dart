import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';

/// One calendar day of the schedule, where the event is.
typedef ScheduleDay = ({DateTime day, List<SessionModel> sessions});

/// One venue's sessions. A null [venue] holds sessions with no venue, or
/// whose venue was removed.
typedef VenueSessions = ({EventVenue? venue, List<SessionModel> sessions});

List<SessionModel> _inOrder(Iterable<SessionModel> sessions) =>
    sessions.toList()..sort((a, b) {
      final byTime = a.startAt.compareTo(b.startAt);
      return byTime != 0 ? byTime : a.title.compareTo(b.title);
    });

/// The schedule grouped by the calendar day each session starts on, in the
/// event's time zone, in time order (Req 48).
List<ScheduleDay> byDay(EventModel event, Iterable<SessionModel> sessions) {
  final days = <DateTime, List<SessionModel>>{};
  for (final s in _inOrder(sessions)) {
    days.putIfAbsent(event.calendarDay(s.startAt), () => []).add(s);
  }
  return [for (final e in days.entries) (day: e.key, sessions: e.value)];
}

/// Every venue in the event's order, including ones with no sessions such as
/// parking, then sessions with no venue (Req 49).
List<VenueSessions> byVenue(EventModel event, Iterable<SessionModel> sessions) {
  final ordered = _inOrder(sessions);
  final ids = {for (final v in event.venues) v.id};
  final rest = [
    for (final s in ordered)
      if (!ids.contains(s.venueId)) s,
  ];
  return [
    for (final v in event.venues)
      (
        venue: v,
        sessions: [
          for (final s in ordered)
            if (s.venueId == v.id) s,
        ],
      ),
    if (rest.isNotEmpty) (venue: null, sessions: rest),
  ];
}

/// The session's venue, or null when it has none or it was removed.
EventVenue? venueOf(EventModel event, SessionModel session) {
  for (final v in event.venues) {
    if (v.id == session.venueId) return v;
  }
  return null;
}

/// Types already used in the event, once each ignoring case, sorted, to
/// suggest while typing. Templates add their own later.
List<String> typeSuggestions(Iterable<SessionModel> sessions) {
  final byKey = <String, String>{};
  for (final s in sessions) {
    final type = s.type?.trim();
    if (type == null || type.isEmpty) continue;
    byKey.putIfAbsent(type.toLowerCase(), () => type);
  }
  return byKey.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Whether [text] is an http or https link, the only kind a venue may open.
bool isWebLink(String text) {
  final uri = Uri.tryParse(text.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

/// Where a venue opens on a map: the organizer's link, or else a search for
/// its address. Null while the address is to be announced.
Uri? mapLinkFor(EventVenue venue) {
  final own = venue.mapUrl?.trim();
  if (own != null && isWebLink(own)) return Uri.parse(own);
  if (venue.addressTba) return null;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': venue.address!.trim(),
  });
}
