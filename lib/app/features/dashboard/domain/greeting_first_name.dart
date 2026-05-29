/// Extracts the first name to use in the Dashboard greeting.
///
/// Returns "there" for null, empty, or whitespace-only input so the greeting
/// stays grammatical ("Good morning, there 👋"). Otherwise returns the first
/// whitespace-separated token.
String greetingFirstName(String? displayName) {
  final trimmed = displayName?.trim() ?? '';
  if (trimmed.isEmpty) return 'there';
  final firstSpace = trimmed.indexOf(' ');
  return firstSpace == -1 ? trimmed : trimmed.substring(0, firstSpace);
}
