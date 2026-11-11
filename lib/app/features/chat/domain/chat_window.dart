import 'package:crewpoint_app/app/core/services/i_chat_service.dart';

/// Chat loads the latest [chatPageSize] messages live, and older pages on
/// demand (Req 57).
const chatPageSize = 50;

/// What changed in an event's latest messages, from one snapshot.
typedef ChatChanges = ({
  /// Messages added or changed.
  List<ChatMessage> upserts,

  /// Messages deleted, never ones that only fell out of the window.
  List<String> deleted,

  /// The whole window, on the first snapshot and the first from the
  /// server, to clear what was deleted while the app was closed. Null
  /// otherwise.
  List<ChatMessage>? window,

  /// Read from the device's cache, without a connection.
  bool fromCache,
});

DateTime? _oldest(List<ChatMessage> window) => window.isEmpty
    ? null
    : window.map((m) => m.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);

/// Which of [removed] were deleted, rather than pushed out of a full window
/// of [limit] by newer messages. A full window's removals older than (or as
/// old as) its oldest message only fell out of it.
List<String> deletedFromWindow({
  required List<ChatMessage> removed,
  required List<ChatMessage> window,
  required int limit,
}) {
  final oldest = _oldest(window);
  final full = window.length >= limit;
  return [
    for (final r in removed)
      if (!full || oldest == null || r.timestamp.isAfter(oldest)) r.id,
  ];
}

/// Cached messages the first live window shows were deleted while away:
/// those within the window's time span but not in it, or everything not in
/// it when the window is not full.
List<String> staleInCache({
  required List<ChatMessage> cached,
  required List<ChatMessage> window,
  required int limit,
}) {
  final ids = {for (final m in window) m.id};
  final oldest = _oldest(window);
  final full = window.length >= limit;
  return [
    for (final c in cached)
      if (!ids.contains(c.id) &&
          (!full || oldest == null || !c.timestamp.isBefore(oldest)))
        c.id,
  ];
}
