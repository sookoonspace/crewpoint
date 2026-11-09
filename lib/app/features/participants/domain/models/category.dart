import 'package:flutter/foundation.dart';

/// A category of participant in an event, such as Child or Adult (Req 42),
/// from `settings.categories`. With [minAge] or [maxAge] it is worked out
/// from a birth date; without, an organizer picks it.
@immutable
class EventCategory {
  const EventCategory({
    required this.id,
    required this.name,
    this.minAge,
    this.maxAge,
    this.isChild = false,
  });

  /// Null when [raw] is not a category.
  static EventCategory? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    return EventCategory(
      id: id,
      name: name,
      minAge: (raw['minAge'] as num?)?.toInt(),
      maxAge: (raw['maxAge'] as num?)?.toInt(),
      isChild: raw['isChild'] == true,
    );
  }

  factory EventCategory.fromMap(Map<String, Object?> map) => tryParse(map)!;

  final String id;
  final String name;

  /// Inclusive bounds on age, in whole years, on the event's date.
  final int? minAge;
  final int? maxAge;

  /// Counts as a child, which only a parent or organizer may enter (Req 40).
  final bool isChild;

  bool get hasAgeRule => minAge != null || maxAge != null;

  bool fits(int age) =>
      (minAge == null || age >= minAge!) && (maxAge == null || age <= maxAge!);

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'minAge': ?minAge,
    'maxAge': ?maxAge,
    if (isChild) 'isChild': true,
  };

  @override
  bool operator ==(Object other) =>
      other is EventCategory &&
      other.id == id &&
      other.name == name &&
      other.minAge == minAge &&
      other.maxAge == maxAge &&
      other.isChild == isChild;

  @override
  int get hashCode => Object.hash(id, name, minAge, maxAge, isChild);
}

/// The event's categories, in order, from its settings.
List<EventCategory> categoriesOf(Map<String, dynamic> settings) {
  final raw = settings['categories'];
  if (raw is! List) return const [];
  return [for (final c in raw) ?EventCategory.tryParse(c)];
}

/// Whole years from [birthDate] (`YYYY-MM-DD`) to [on]. Someone born on
/// 29 February turns a year older on 1 March in other years.
int? ageOn(String? birthDate, DateTime on) {
  final born = birthDate == null ? null : DateTime.tryParse(birthDate);
  if (born == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birthDate!)) {
    return null;
  }
  var age = on.year - born.year;
  final hadBirthday =
      on.month > born.month || (on.month == born.month && on.day >= born.day);
  if (!hadBirthday) age--;
  return age;
}

/// The first category whose age rule fits someone born on [birthDate], on
/// [on] (the event's start). Null without a birth date or a fitting rule.
EventCategory? categoryFor(
  String? birthDate,
  DateTime on,
  List<EventCategory> categories,
) {
  final age = ageOn(birthDate, on);
  if (age == null) return null;
  for (final c in categories) {
    if (c.hasAgeRule && c.fits(age)) return c;
  }
  return null;
}
