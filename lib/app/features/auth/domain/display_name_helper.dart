/// Resolves a fallback display name from an email address.
///
/// Used when an auth provider returns null/empty `displayName` (notably Apple
/// after first sign-in). The local-part is extracted, stripped of any `+`-tag,
/// split on `.`/`_`/`-`, title-cased per token, and joined with spaces.
///
/// Returns `'CrewPoint user'` when [email] is null/empty or has no usable
/// local-part.
String deriveDisplayNameFromEmail(String? email) {
  const fallback = 'CrewPoint user';
  if (email == null || email.isEmpty) return fallback;
  final atIndex = email.indexOf('@');
  if (atIndex <= 0) return fallback;
  var local = email.substring(0, atIndex);
  final plusIndex = local.indexOf('+');
  if (plusIndex >= 0) local = local.substring(0, plusIndex);
  final tokens = local
      .split(RegExp(r'[._\-]'))
      .where((t) => t.isNotEmpty)
      .map(_titleCase)
      .toList();
  if (tokens.isEmpty) return fallback;
  return tokens.join(' ');
}

String _titleCase(String token) {
  if (token.isEmpty) return token;
  final head = token[0].toUpperCase();
  final tail = token.substring(1).toLowerCase();
  return '$head$tail';
}
