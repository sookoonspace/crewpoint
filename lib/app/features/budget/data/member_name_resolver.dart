/// Reserved for the budget + tasks PDF / CSV report layer.
///
/// Resolves a `uid` against a `memberNames` map for the active event.
/// When the `uid` is absent, null, or maps to an empty string, returns
/// the canonical placeholder `'(no longer in event)'` so reports never
/// surface raw UIDs to readers.
const String kRemovedMemberPlaceholder = '(no longer in event)';

String resolveMemberName({
  required String? uid,
  required Map<String, String> memberNames,
}) {
  if (uid == null) return kRemovedMemberPlaceholder;
  final name = memberNames[uid];
  if (name == null || name.isEmpty) return kRemovedMemberPlaceholder;
  return name;
}
