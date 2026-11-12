import 'package:flutter/foundation.dart';

/// A system template as the picker shows it (Req 62). The files live in
/// `assets/templates/`; `createEvent` copies the rest into the event.
@immutable
class EventTemplateInfo {
  const EventTemplateInfo({
    required this.id,
    required this.version,
    required this.names,
    required this.descriptions,
    required this.icon,
    required this.fastPath,
  });

  /// Reads one template file, refusing a damaged one.
  factory EventTemplateInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final version = json['version'];
    if (id is! String || version is! int) {
      throw const FormatException('Not a template.');
    }
    Map<String, String> text(Object? raw) => {
      if (raw is Map)
        for (final e in raw.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
    };
    return EventTemplateInfo(
      id: id,
      version: version,
      names: text(json['name']),
      descriptions: text(json['description']),
      icon: json['icon'] as String? ?? id,
      fastPath: json['fastPath'] == true,
    );
  }

  /// The template IDs in `index.json`, in order.
  static List<String> idsFrom(Map<String, dynamic> index) => [
    for (final id in (index['templates'] as List<dynamic>? ?? const []))
      if (id is String) id,
  ];

  static const assetDir = 'assets/templates';

  final String id;
  final int version;
  final Map<String, String> names;
  final Map<String, String> descriptions;
  final String icon;

  /// Created with only a title and a date, with no further screens (Req
  /// 63).
  final bool fastPath;

  String name(String language) => names[language] ?? names['en'] ?? id;

  String description(String language) =>
      descriptions[language] ?? descriptions['en'] ?? '';
}
