import 'package:flutter/foundation.dart';

/// An account whose verified email matched more than one adult record, or
/// only children, in an event (Req 46). `events/{eventId}/linkRequests/{uid}`,
/// written only by the server and read with `participants.readPrivate`,
/// because it shows the email. An organizer settles it.
@immutable
class LinkRequest {
  const LinkRequest({
    required this.uid,
    this.name,
    required this.email,
    this.participantIds = const [],
    this.groupIds = const [],
  });

  factory LinkRequest.fromFirestore(String uid, Map<String, dynamic> data) =>
      LinkRequest(
        uid: uid,
        name: data['name'] as String?,
        email: data['email'] as String? ?? '',
        participantIds: _strings(data['participantIds']),
        groupIds: _strings(data['groupIds']),
      );

  final String uid;

  /// The account's name, when it has one.
  final String? name;
  final String email;

  /// The records carrying the email, adults and children.
  final List<String> participantIds;

  /// Their groups, offered when only children matched.
  final List<String> groupIds;

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  @override
  bool operator ==(Object other) =>
      other is LinkRequest &&
      other.uid == uid &&
      other.name == name &&
      other.email == email &&
      listEquals(other.participantIds, participantIds) &&
      listEquals(other.groupIds, groupIds);

  @override
  int get hashCode => Object.hash(
    uid,
    name,
    email,
    Object.hashAll(participantIds),
    Object.hashAll(groupIds),
  );
}
