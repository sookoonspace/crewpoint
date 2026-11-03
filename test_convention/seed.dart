import 'dart:convert';
import 'dart:io';

/// Loads the convention fixture. Pure Dart, no app imports: the app has no
/// family or registration model to load this into (see the report).
class ConventionSeed {
  ConventionSeed(this.raw);

  factory ConventionSeed.load() => ConventionSeed(
    jsonDecode(
          File(
            'test_convention/fixtures/derod_convention_2027_v3.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>,
  );

  final Map<String, dynamic> raw;

  List<Map<String, dynamic>> get families =>
      (raw['families'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get others =>
      (raw['otherFamilies'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get items =>
      (raw['sponsorItems'] as List).cast<Map<String, dynamic>>();
  List<String> get meals => (raw['meals'] as List).cast<String>();

  static List<Map<String, dynamic>> people(Map<String, dynamic> family) =>
      (family['people'] as List).cast<Map<String, dynamic>>();
}

/// Oracle for the hybrid fee rule in §1. Lives in the tests because the app
/// has no fee logic to call.
int familyFee(Map<String, dynamic> family) {
  final adults = ConventionSeed.people(
    family,
  ).where((p) => (p['age'] as int) >= 18).length;
  return 300 + (adults > 2 ? (adults - 2) * 150 : 0);
}

/// Deterministic scale fixture from §3: 108 families, 400 people.
List<List<int>> scaleFamilies() {
  const pattern = [4, 3, 7, 1, 5, 2, 4];
  final out = <List<int>>[];
  var people = 0;
  var i = 0;
  while (out.length < 107) {
    final size = pattern[i % pattern.length];
    out.add([out.length, size]);
    people += size;
    i++;
  }
  out.add([107, 400 - people]);
  return out;
}
