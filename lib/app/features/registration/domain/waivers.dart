import 'package:flutter/foundation.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// Waivers (Spec #233 Req 26-29; #246): the pure rules run the cases in
/// `functions/test/fixtures/waiver_cases.json`, as the server's
/// `functions/src/registration/waivers.ts` does; change them together.

/// Everyone, one category, or the people signed up for one session.
@immutable
class WaiverAppliesTo {
  const WaiverAppliesTo.everyone() : kind = 'everyone', id = null;
  const WaiverAppliesTo.category(String this.id) : kind = 'category';
  const WaiverAppliesTo.session(String this.id) : kind = 'session';

  static WaiverAppliesTo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    return switch (raw['kind']) {
      'everyone' => const WaiverAppliesTo.everyone(),
      'category' when id is String => WaiverAppliesTo.category(id),
      'session' when id is String => WaiverAppliesTo.session(id),
      _ => null,
    };
  }

  final String kind;
  final String? id;

  Map<String, String> toMap() => {'kind': kind, 'id': ?id};

  @override
  bool operator ==(Object other) =>
      other is WaiverAppliesTo && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

bool waiverApplies(
  WaiverAppliesTo appliesTo, {
  required String? categoryId,
  required Set<String> signUps,
}) => switch (appliesTo.kind) {
  'everyone' => true,
  'category' => categoryId == appliesTo.id,
  'session' => signUps.contains(appliesTo.id),
  _ => false,
};

enum AcceptanceStatus { current, earlier, missing }

/// How an acceptance of version [accepted] (null when never accepted)
/// stands against the waiver's current [version]. An earlier version still
/// counts unless the organizer requires the latest (Req 28).
({AcceptanceStatus status, bool counts}) acceptanceStatus({
  required int version,
  required bool requireLatest,
  required int? accepted,
}) {
  if (accepted == null) return (status: AcceptanceStatus.missing, counts: false);
  if (accepted >= version) return (status: AcceptanceStatus.current, counts: true);
  return (status: AcceptanceStatus.earlier, counts: !requireLatest);
}

/// One waiver as the form and settings show it (Req 26).
@immutable
class Waiver {
  const Waiver({
    required this.id,
    required this.title,
    required this.text,
    this.version = 1,
    this.appliesTo = const WaiverAppliesTo.everyone(),
    this.required = false,
    this.requireLatest = true,
  });

  static Waiver? tryParse(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    final title = LocalText.tryParse(raw['title']);
    final text = LocalText.tryParse(raw['text']);
    if (title == null || text == null) return null;
    return Waiver(
      id: raw['id'] as String,
      title: title,
      text: text,
      version: (raw['version'] as num?)?.toInt() ?? 1,
      appliesTo:
          WaiverAppliesTo.tryParse(raw['appliesTo']) ??
          const WaiverAppliesTo.everyone(),
      required: raw['required'] == true,
      requireLatest: raw['requireLatest'] != false,
    );
  }

  final String id;
  final LocalText title;
  final LocalText text;
  final int version;
  final WaiverAppliesTo appliesTo;

  /// Whether accepting it is needed to register (Req 29).
  final bool required;

  /// Whether people who accepted an earlier version must accept again.
  final bool requireLatest;
}
