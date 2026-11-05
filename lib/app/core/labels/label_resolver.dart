/// The default words for each concept, from one data file that the app and the
/// backend both read, so the two cannot drift apart (Req 20).
class LabelDefaults {
  LabelDefaults.fromJson(Map<String, dynamic> json)
    : _forms = {
        for (final entry in json.entries)
          entry.key: (entry.value as Map<String, dynamic>)
              .cast<String, String>(),
      };

  /// Inside `functions/src` so the deployed functions bundle the same file.
  static const assetPath = 'functions/src/shared/label_defaults.json';

  /// Set once at startup, before the app runs.
  static late LabelDefaults current;

  final Map<String, Map<String, String>> _forms;

  /// Every concept, in the order settings shows them.
  List<String> get concepts => [..._forms.keys];

  String form(String concept, String form) {
    final forms = _forms[concept];
    if (forms == null) throw ArgumentError.value(concept, 'concept');
    return forms[form]!;
  }
}

/// Returns an event's word for a concept, or the default, in singular or plural.
class LabelResolver {
  const LabelResolver(this._labels);

  final Map<String, dynamic> _labels;

  /// The label's text for [form], or null when it is unset or badly shaped.
  String? _custom(String concept, String form) {
    final label = _labels[concept];
    if (label is! Map) return null;
    final text = label[form];
    return text is String && text.trim().isNotEmpty ? text.trim() : null;
  }

  /// The word the organizer typed for this exact form, if any.
  String? customForm(String concept, String form) => _custom(concept, form);

  String one(String concept) =>
      _custom(concept, 'one') ??
      _custom(concept, 'other') ??
      LabelDefaults.current.form(concept, 'one');

  String other(String concept) =>
      _custom(concept, 'other') ??
      _custom(concept, 'one') ??
      LabelDefaults.current.form(concept, 'other');

  /// For running text, such as "3 members".
  String count(String concept, int n) =>
      '$n ${(n == 1 ? one(concept) : other(concept)).toLowerCase()}';
}
