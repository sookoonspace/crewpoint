// Scanner for the design guard (Spec #186 Req 16, ledger L18). Pure Dart,
// with no app imports.
import 'dart:io';

/// The one folder allowed to hold style values.
const designFolder = 'lib/app/core/design/';

/// Files allowed to break a rule for good, as `{path: reason}`. Add an entry
/// only with a reason.
const Map<String, String> listedExceptions = {};

class StyleHit {
  const StyleHit(this.path, this.line, this.rule);

  final String path;
  final int line;
  final String rule;

  @override
  String toString() => '$path:$line: $rule';
}

/// App source outside the design system, leaving out generated Dart.
List<File> guardedFiles() => [
  for (final entity in Directory('lib').listSync(recursive: true))
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.endsWith('.g.dart') &&
        !entity.path.startsWith(designFolder) &&
        !RegExp(r'^lib/firebase_options_\w+\.dart$').hasMatch(entity.path))
      entity,
];

const _materialWidgets = [
  'Card',
  'ListTile',
  'Chip',
  'ChoiceChip',
  'FilterChip',
  'InputChip',
  'ElevatedButton',
  'FilledButton',
  'OutlinedButton',
  'TextButton',
];

/// Constructors whose arguments must not be bare non-zero numbers.
const _sized = [
  'EdgeInsets',
  'EdgeInsetsDirectional',
  'SizedBox',
  'BorderRadius',
  'BorderRadiusDirectional',
  'Radius',
];

final _simpleRules = <String, RegExp>{
  'Color(0x…)': RegExp(r'\bColor\(\s*0x'),
  'Colors.…': RegExp(r'(?<![\w.])Colors\.'),
  'GoogleFonts': RegExp(r'\bGoogleFonts\b'),
  'fontFamily:': RegExp(r'\bfontFamily\s*:'),
  for (final name in _materialWidgets)
    // `Card(`, `TextButton.icon(`; `ElevatedButton.styleFrom(` is a style
    // helper, not a widget.
    name: RegExp('(?<![\\w.])$name(?:\\.(?!styleFrom\\b)\\w+)?\\s*\\('),
};

final _sizedCall = RegExp(
  '(?<![\\w.])(${_sized.join('|')})(?:\\.\\w+)?\\s*\\(',
);
final _numberLiteral = RegExp(r'^-?\d+(?:\.\d+)?$');

/// Every rule [source] breaks.
List<StyleHit> findStyleHits(String path, String source) {
  final code = blankCommentsAndStrings(source);
  int lineOf(int offset) =>
      '\n'.allMatches(code.substring(0, offset)).length + 1;
  final hits = <StyleHit>[
    for (final rule in _simpleRules.entries)
      for (final match in rule.value.allMatches(code))
        StyleHit(path, lineOf(match.start), rule.key),
  ];
  for (final match in _sizedCall.allMatches(code)) {
    final open = match.end - 1;
    final close = _closingParen(code, open);
    if (close < 0) continue;
    for (final argument in _topLevelArguments(
      code.substring(open + 1, close),
    )) {
      final value = argument.contains(':')
          ? argument.substring(argument.indexOf(':') + 1).trim()
          : argument.trim();
      if (_numberLiteral.hasMatch(value) && double.parse(value) != 0) {
        hits.add(StyleHit(path, lineOf(match.start), 'number in ${match[1]}'));
        break;
      }
    }
  }
  hits.sort((a, b) => a.line.compareTo(b.line));
  return hits;
}

int _closingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

List<String> _topLevelArguments(String inside) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < inside.length; i++) {
    final c = inside[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ',' && depth == 0) {
      parts.add(inside.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(inside.substring(start));
  return [
    for (final p in parts)
      if (p.trim().isNotEmpty) p,
  ];
}

/// [source] with comments and the contents of string literals replaced by
/// spaces, keeping line breaks so line numbers stay right.
String blankCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  void blank(int end) {
    for (; i < end && i < source.length; i++) {
      out.write(source[i] == '\n' ? '\n' : ' ');
    }
  }

  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      blank(end < 0 ? source.length : end);
    } else if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      blank(end < 0 ? source.length : end + 2);
    } else if (source[i] == "'" || source[i] == '"') {
      final quote = source.startsWith("'''", i) || source.startsWith('"""', i)
          ? source.substring(i, i + 3)
          : source[i];
      final raw = i > 0 && source[i - 1] == 'r';
      out.write(quote);
      i += quote.length;
      var end = i;
      while (end < source.length && !source.startsWith(quote, end)) {
        if (!raw && source[end] == r'\') end++;
        if (quote.length == 1 && end < source.length && source[end] == '\n') {
          break;
        }
        end++;
      }
      blank(end);
      if (source.startsWith(quote, i)) {
        out.write(quote);
        i += quote.length;
      }
    } else {
      out.write(source[i]);
      i++;
    }
  }
  return out.toString();
}
