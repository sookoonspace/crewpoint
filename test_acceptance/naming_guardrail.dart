// Scanner for the naming guardrail in Req 2. Pure Dart, with no app imports.
import 'dart:io';

const bannedWords = {
  'family',
  'meal',
  'derod',
  'wedding',
  'cricket',
  'golf',
  'tee',
};

/// Exceptions beyond comments, Riverpod's `.family` and `fontFamily`, as
/// `{file path: {words}}`. Template data is outside the scanned folders, so it
/// needs no entry here. Add an entry only with a reason beside it.
const Map<String, Set<String>> listedExceptions = {};

class BannedWordHit {
  const BannedWordHit(this.path, this.line, this.word);

  final String path;
  final int line;
  final String word;

  @override
  String toString() => '$path:$line: $word';
}

/// App and backend source files, leaving out generated Dart.
List<File> guardedFiles() => [
  for (final dir in const ['lib', 'functions/src'])
    for (final entity in Directory(dir).listSync(recursive: true))
      if (entity is File &&
          RegExp(r'\.(dart|ts|json)$').hasMatch(entity.path) &&
          !entity.path.endsWith('.g.dart'))
        entity,
];

List<BannedWordHit> findBannedWords(
  String path,
  String source, {
  Map<String, Set<String>> allowed = listedExceptions,
}) {
  final language = path.endsWith('.ts')
      ? _Language.typescript
      : path.endsWith('.json')
      ? _Language.json
      : _Language.dart;
  final code = _withoutExemptNames(_Lexer(source, language).withoutComments());
  final hits = <BannedWordHit>[];
  for (final token in RegExp(r'[A-Za-z0-9_$]+').allMatches(code)) {
    for (final word in _wordsIn(token[0]!)) {
      if (bannedWords.contains(word) &&
          !(allowed[path]?.contains(word) ?? false)) {
        final line = '\n'.allMatches(code.substring(0, token.start)).length + 1;
        hits.add(BannedWordHit(path, line, word));
      }
    }
  }
  return hits;
}

/// Blanks `.family` and `fontFamily`, keeping line numbers.
String _withoutExemptNames(String code) => code.replaceAllMapped(
  RegExp(r'\.\s*family\b|\bfontFamily(?:Fallback)?\b'),
  (m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' '),
);

/// Splits `mealCount`, `meal_count`, `MEAL2` and `HTMLMeal` into lower-case words.
Iterable<String> _wordsIn(String token) => token
    .split(
      RegExp(
        r'[_$]+|(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])|(?<=[A-Za-z])(?=[0-9])|(?<=[0-9])(?=[A-Za-z])',
      ),
    )
    .map((word) => word.toLowerCase());

enum _Language { dart, typescript, json }

/// Finds comments by following strings, so `//` in a URL is not a comment and an
/// apostrophe in a comment does not open a string. Comments become spaces, and
/// everything else stays, because identifiers and strings are both checked.
class _Lexer {
  _Lexer(String source, this.language) : _chars = source.split('');

  final _Language language;
  final List<String> _chars;
  int _i = 0;

  String withoutComments() {
    if (language != _Language.json) _code(insideInterpolation: false);
    return _chars.join();
  }

  bool get _isDart => language == _Language.dart;
  bool _at(int i, String c) => i < _chars.length && _chars[i] == c;

  void _code({required bool insideInterpolation}) {
    var depth = 0;
    while (_i < _chars.length) {
      final c = _chars[_i];
      if (c == '/' && _at(_i + 1, '/')) {
        _lineComment();
      } else if (c == '/' && _at(_i + 1, '*')) {
        _blockComment();
      } else if (c == '/' && !_isDart && _startsRegex()) {
        _regex();
      } else if (c == "'" || c == '"' || (c == '`' && !_isDart)) {
        _string(c);
      } else if (c == '{') {
        depth++;
        _i++;
      } else if (c == '}') {
        if (insideInterpolation && depth == 0) return;
        depth--;
        _i++;
      } else {
        _i++;
      }
    }
  }

  void _blank(int from, int to) {
    for (var k = from; k < to && k < _chars.length; k++) {
      if (_chars[k] != '\n') _chars[k] = ' ';
    }
  }

  void _lineComment() {
    final start = _i;
    while (_i < _chars.length && _chars[_i] != '\n') {
      _i++;
    }
    _blank(start, _i);
  }

  void _blockComment() {
    final start = _i;
    var depth = 0;
    while (_i < _chars.length) {
      if (_at(_i, '/') && _at(_i + 1, '*') && (_isDart || depth == 0)) {
        depth++;
        _i += 2;
      } else if (_at(_i, '*') && _at(_i + 1, '/')) {
        depth--;
        _i += 2;
        if (depth == 0) break;
      } else {
        _i++;
      }
    }
    _blank(start, _i);
  }

  void _string(String quote) {
    final raw = _isDart && _i > 0 && _chars[_i - 1] == 'r';
    final triple = _isDart && _at(_i + 1, quote) && _at(_i + 2, quote);
    final multiline = triple || quote == '`';
    final interpolates = _isDart || quote == '`';
    _i += triple ? 3 : 1;
    while (_i < _chars.length) {
      final c = _chars[_i];
      if (c == '\\' && !raw) {
        _i += 2;
      } else if (c == '\n' && !multiline) {
        return;
      } else if (c == r'$' && _at(_i + 1, '{') && interpolates && !raw) {
        _i += 2;
        _code(insideInterpolation: true);
        _i++;
      } else if (c == quote &&
          (!triple || (_at(_i + 1, quote) && _at(_i + 2, quote)))) {
        _i += triple ? 3 : 1;
        return;
      } else {
        _i++;
      }
    }
  }

  /// A `/` starts a regex after an operator or `return`, and divides otherwise.
  bool _startsRegex() {
    var k = _i - 1;
    while (k >= 0 && (_chars[k] == ' ' || _chars[k] == '\t')) {
      k--;
    }
    if (k < 0 || '\n(=,:;!&|?{}[+-*%<>~^'.contains(_chars[k])) {
      return _closesOnLine();
    }
    final before = _chars.sublist((k - 5).clamp(0, k), k + 1).join();
    return before.endsWith('return') && _closesOnLine();
  }

  bool _closesOnLine() {
    var inClass = false;
    for (var k = _i + 1; k < _chars.length && _chars[k] != '\n'; k++) {
      final c = _chars[k];
      if (c == '\\') {
        k++;
      } else if (c == '[') {
        inClass = true;
      } else if (c == ']') {
        inClass = false;
      } else if (c == '/' && !inClass) {
        return true;
      }
    }
    return false;
  }

  void _regex() {
    var inClass = false;
    _i++;
    while (_i < _chars.length && _chars[_i] != '\n') {
      final c = _chars[_i];
      if (c == '\\') {
        _i += 2;
        continue;
      }
      if (c == '[') {
        inClass = true;
      }
      if (c == ']') {
        inClass = false;
      }
      _i++;
      if (c == '/' && !inClass) {
        return;
      }
    }
  }
}
