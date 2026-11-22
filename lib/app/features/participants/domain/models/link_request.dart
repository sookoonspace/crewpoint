import 'package:flutter/foundation.dart';

/// An account whose verified email or phone matched more than one adult
/// record, or only children, in an event (Req 46, Spec #233 Req 13).
/// `events/{eventId}/linkRequests/{uid}`, written only by the server and
/// read with `participants.readPrivate`, because it shows the email and
/// phone. An organizer settles it.
@immutable
class LinkRequest {
  const LinkRequest({
    required this.uid,
    this.name,
    required this.email,
    this.phone,
    this.participantIds = const [],
    this.groupIds = const [],
  });

  factory LinkRequest.fromFirestore(String uid, Map<String, dynamic> data) =>
      LinkRequest(
        uid: uid,
        name: data['name'] as String?,
        email: data['email'] as String? ?? '',
        phone: data['phone'] as String?,
        participantIds: _strings(data['participantIds']),
        groupIds: _strings(data['groupIds']),
      );

  final String uid;

  /// The account's name, when it has one.
  final String? name;
  /// Empty for an account signed in by phone alone.
  final String email;

  /// E.164, for an account signed in by phone.
  final String? phone;

  /// How the account is reached: its email and phone, whichever it has.
  String get contact =>
      [email, ?phone].where((s) => s.isNotEmpty).join(' · ');

  /// The records carrying the email or phone, adults and children.
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
      other.phone == phone &&
      listEquals(other.participantIds, participantIds) &&
      listEquals(other.groupIds, groupIds);

  @override
  int get hashCode => Object.hash(
    uid,
    name,
    email,
    phone,
    Object.hashAll(participantIds),
    Object.hashAll(groupIds),
  );
}
