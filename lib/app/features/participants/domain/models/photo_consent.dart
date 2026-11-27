import 'package:flutter/foundation.dart';

/// Someone on the photo consent list (Spec #233 Req 30; #247): who said no
/// to photos and videos, or has not answered. Only what a photographer
/// needs: a name, group name and age band.
@immutable
class PhotoConsentEntry {
  const PhotoConsentEntry({
    required this.id,
    required this.name,
    this.groupName = '',
    this.ageBand = '',
    required this.saidNo,
  });

  final String id;
  final String name;
  final String groupName;
  final String ageBand;

  /// True for no; false for not answered yet, which is treated as no.
  final bool saidNo;
}

/// `events/{id}/photoConsent/current`, kept by the server and read only
/// with `photoConsent.read`.
@immutable
class PhotoConsentList {
  const PhotoConsentList(this.people);

  factory PhotoConsentList.fromFirestore(Map<String, dynamic> data) {
    final raw = data['people'];
    return PhotoConsentList([
      if (raw is Map)
        for (final e in raw.entries)
          if (e.value is Map)
            PhotoConsentEntry(
              id: '${e.key}',
              name: (e.value as Map)['name'] as String? ?? '',
              groupName: (e.value as Map)['groupName'] as String? ?? '',
              ageBand: (e.value as Map)['ageBand'] as String? ?? '',
              saidNo: (e.value as Map)['answer'] == 'no',
            ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
  }

  final List<PhotoConsentEntry> people;

  /// Those whose name, group or age band contains [search], ignoring case.
  List<PhotoConsentEntry> matching(String search) {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return people;
    return [
      for (final p in people)
        if ('${p.name} ${p.groupName}'.toLowerCase().contains(q)) p,
    ];
  }
}
