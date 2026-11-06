/// Whether [current] is older than [minimum]. Both are `major.minor.patch`.
/// A build number after `+` is ignored, and missing parts count as zero.
/// A version that cannot be read never blocks the app.
bool isBelowMinimum({required String current, required String minimum}) {
  final a = _parts(current);
  final b = _parts(minimum);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}

List<int>? _parts(String version) {
  final numbers = version
      .split('+')
      .first
      .split('.')
      .map(int.tryParse)
      .toList();
  if (numbers.isEmpty || numbers.length > 3 || numbers.contains(null)) {
    return null;
  }
  return [...numbers.cast<int>(), 0, 0, 0].take(3).toList();
}
