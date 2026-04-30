// Builds Flutter assets and hosted-static HTML from the Markdown
// source in `docs/legal/`.
//
// Two outputs per source file:
//
//   docs/legal/privacy-policy.md
//     ├── assets/legal/privacy-policy.md   (copy — bundled with the app)
//     └── web/legal/privacy.html            (self-contained HTML page)
//
//   docs/legal/terms-of-service.md
//     ├── assets/legal/terms-of-service.md  (copy)
//     └── web/legal/terms.html               (self-contained)
//
// The HTML pages use inline styles only (no external CSS / JS) so
// they render correctly under Firebase Hosting cache and on every
// browser. A `<meta name="robots" content="noindex">` tag is included
// pre-launch; remove on launch flip per the pre-launch checklist.
//
// Usage:
//   dart run scripts/build_legal_html.dart
//
// Idempotent — re-run after every edit to `docs/legal/*.md`.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:markdown/markdown.dart' as md;
import 'package:yaml/yaml.dart';

const _docsDir = 'docs/legal';
const _assetsDir = 'assets/legal';
const _webDir = 'web/legal';

const _frontmatterPattern = r'^---\r?\n([\s\S]*?)\r?\n---\r?\n';

class _LegalDoc {
  const _LegalDoc({
    required this.sourceFilename,
    required this.assetFilename,
    required this.htmlFilename,
    required this.title,
  });

  final String sourceFilename;
  final String assetFilename;
  final String htmlFilename;
  final String title;
}

const _docs = <_LegalDoc>[
  _LegalDoc(
    sourceFilename: 'privacy-policy.md',
    assetFilename: 'privacy-policy.md',
    htmlFilename: 'privacy.html',
    title: 'CrewPoint Privacy Policy',
  ),
  _LegalDoc(
    sourceFilename: 'terms-of-service.md',
    assetFilename: 'terms-of-service.md',
    htmlFilename: 'terms.html',
    title: 'CrewPoint Terms of Service',
  ),
];

void main() {
  Directory(_assetsDir).createSync(recursive: true);
  Directory(_webDir).createSync(recursive: true);

  for (final doc in _docs) {
    final source = File('$_docsDir/${doc.sourceFilename}');
    if (!source.existsSync()) {
      stderr.writeln('Missing source: ${source.path}');
      exit(1);
    }
    final raw = source.readAsStringSync();

    File('$_assetsDir/${doc.assetFilename}').writeAsStringSync(raw);

    final (frontmatter, body) = _splitFrontmatter(raw);
    final html = _renderHtml(
      title: doc.title,
      frontmatter: frontmatter,
      body: body,
    );
    File('$_webDir/${doc.htmlFilename}').writeAsStringSync(html);

    print('built: $_webDir/${doc.htmlFilename}');
  }
}

(Map<String, String>, String) _splitFrontmatter(String raw) {
  final match = RegExp(_frontmatterPattern).firstMatch(raw);
  if (match == null) return (<String, String>{}, raw);
  final yamlBlock = match.group(1) ?? '';
  final body = raw.substring(match.end);
  final parsed = loadYaml(yamlBlock);
  final out = <String, String>{};
  if (parsed is YamlMap) {
    parsed.forEach((k, v) {
      out[k.toString()] = v.toString();
    });
  }
  return (out, body);
}

String _renderHtml({
  required String title,
  required Map<String, String> frontmatter,
  required String body,
}) {
  final bodyHtml = md.markdownToHtml(
    body,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  final stamp = StringBuffer();
  if (frontmatter.containsKey('effective_date') ||
      frontmatter.containsKey('last_updated')) {
    stamp.writeln('<p class="stamp">');
    if (frontmatter.containsKey('effective_date')) {
      stamp.writeln(
        '<strong>Effective:</strong> '
        '${_escape(frontmatter['effective_date']!)} &nbsp;•&nbsp; ',
      );
    }
    if (frontmatter.containsKey('last_updated')) {
      stamp.writeln(
        '<strong>Last updated:</strong> '
        '${_escape(frontmatter['last_updated']!)}',
      );
    }
    stamp.writeln('</p>');
  }
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<title>${_escape(title)}</title>
<style>
  :root {
    --fg: #2D3436;
    --muted: #636E72;
    --bg: #F8F9FA;
    --accent: #4A6B5A;
    --rule: #DFE6E9;
  }
  body {
    margin: 0;
    background: var(--bg);
    color: var(--fg);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    font-size: 16px;
    line-height: 1.6;
  }
  main {
    max-width: 720px;
    margin: 0 auto;
    padding: 32px 20px 64px;
  }
  h1 { font-size: 1.875rem; margin: 0 0 8px; color: var(--fg); }
  h2 { font-size: 1.375rem; margin: 32px 0 8px; color: var(--accent); }
  h3 { font-size: 1.125rem; margin: 24px 0 6px; color: var(--fg); }
  p, ul, ol { margin: 12px 0; }
  ul, ol { padding-left: 24px; }
  hr { border: 0; border-top: 1px solid var(--rule); margin: 32px 0; }
  blockquote {
    border-left: 3px solid var(--accent);
    margin: 16px 0;
    padding: 4px 16px;
    color: var(--muted);
    background: rgba(74,107,90,0.05);
  }
  a { color: var(--accent); }
  code {
    background: rgba(45,52,54,0.08);
    padding: 1px 5px;
    border-radius: 3px;
    font-size: 0.9em;
  }
  .stamp {
    color: var(--muted);
    font-size: 0.95rem;
    margin-bottom: 28px;
  }
  .footer {
    margin-top: 48px;
    color: var(--muted);
    font-size: 0.85rem;
    border-top: 1px solid var(--rule);
    padding-top: 16px;
  }
</style>
</head>
<body>
<main>
$stamp
$bodyHtml
<p class="footer">
&copy; Sookoon. CrewPoint Privacy Policy + Terms of Service are also bundled inside the app under <em>Profile → Privacy Dashboard → Legal Documents</em>.
</p>
</main>
</body>
</html>
''';
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
