import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';

/// Renders a bundled markdown document (Privacy Policy / Terms of
/// Service) with the YAML frontmatter parsed and surfaced above the
/// body.
///
/// Asset-load failure path: a `_LoadFailure` placeholder with a
/// "View hosted version" button that opens [hostedUrl] via
/// `url_launcher`. Logs the failure via `dart:developer`.
class MarkdownRenderScreen extends StatefulWidget {
  const MarkdownRenderScreen({
    super.key,
    required this.title,
    required this.assetPath,
    required this.hostedUrl,
  });

  final String title;
  final String assetPath;
  final String hostedUrl;

  @override
  State<MarkdownRenderScreen> createState() => _MarkdownRenderScreenState();
}

class _MarkdownRenderScreenState extends State<MarkdownRenderScreen> {
  Future<_MarkdownDoc?>? _doc;

  @override
  void initState() {
    super.initState();
    _doc = _loadAsset();
  }

  Future<_MarkdownDoc?> _loadAsset() async {
    try {
      final raw = await rootBundle.loadString(widget.assetPath);
      return _MarkdownDoc.parse(raw);
    } catch (e, st) {
      log(
        'Failed to load legal asset ${widget.assetPath}',
        error: e,
        stackTrace: st,
        name: 'profile',
      );
      return null;
    }
  }

  Future<void> _launchHosted() async {
    final uri = Uri.parse(widget.hostedUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.privacy.couldNotOpen(widget.hostedUrl)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: widget.title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
      ),
      body: FutureBuilder<_MarkdownDoc?>(
        future: _doc,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return CpLoadingState(semanticLabel: widget.title);
          }
          final doc = snap.data;
          if (doc == null) {
            return _LoadFailure(
              hostedUrl: widget.hostedUrl,
              onLaunch: _launchHosted,
            );
          }
          return _RenderedMarkdown(doc: doc, onLaunchHosted: _launchHosted);
        },
      ),
    );
  }
}

class _RenderedMarkdown extends StatelessWidget {
  const _RenderedMarkdown({required this.doc, required this.onLaunchHosted});

  final _MarkdownDoc doc;
  final VoidCallback onLaunchHosted;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.privacy;
    final effective = doc.frontmatter['effective_date'];
    final updated = doc.frontmatter['last_updated'];
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.md,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        ContentMaxWidth(
          key: const Key('markdown.body.clamped'),
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: [
              if (effective != null || updated != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.xs,
                  children: [
                    if (effective != null)
                      _StampLine(
                        key: const Key('legal.stamp.effective'),
                        label: s.effective,
                        value: effective,
                      ),
                    if (updated != null)
                      _StampLine(
                        key: const Key('legal.stamp.lastUpdated'),
                        label: s.lastUpdated,
                        value: updated,
                      ),
                  ],
                ),
              MarkdownBody(
                key: const Key('legal.markdown.body'),
                data: doc.body,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                  h1: cp.type.headlineSmall.copyWith(color: cp.colors.text),
                  h2: cp.type.titleLarge.copyWith(color: cp.colors.text),
                  h3: cp.type.titleMedium.copyWith(color: cp.colors.text),
                  listBullet: cp.type.bodyMedium.copyWith(
                    color: cp.colors.text,
                  ),
                  a: cp.type.bodyMedium.copyWith(color: cp.colors.accent),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: CpButton.secondary(
                  key: const Key('legal.viewHosted'),
                  label: s.viewHosted,
                  icon: CpIcons.actionOpenInNew,
                  onPressed: onLaunchHosted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StampLine extends StatelessWidget {
  const _StampLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: cp.type.labelLarge.copyWith(color: cp.colors.textMuted),
          ),
          TextSpan(
            text: value,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.hostedUrl, required this.onLaunch});

  final String hostedUrl;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.privacy;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(cp.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: cp.space.md,
          children: [
            Icon(
              CpIcons.cloudOff,
              size: cp.sizes.iconXl,
              color: cp.colors.textMuted,
            ),
            Text(
              s.loadFailed,
              textAlign: TextAlign.center,
              style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
            ),
            CpButton.secondary(
              key: const Key('legal.fallback.viewOnline'),
              label: s.viewOnline,
              icon: CpIcons.actionOpenInNew,
              onPressed: onLaunch,
            ),
            Text(
              hostedUrl,
              textAlign: TextAlign.center,
              style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splits YAML frontmatter from a markdown body.
class _MarkdownDoc {
  const _MarkdownDoc({required this.frontmatter, required this.body});

  static final RegExp _frontmatterPattern = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---\r?\n',
  );

  final Map<String, String> frontmatter;
  final String body;

  factory _MarkdownDoc.parse(String raw) {
    final match = _frontmatterPattern.firstMatch(raw);
    if (match == null) {
      return _MarkdownDoc(frontmatter: const {}, body: raw);
    }
    final yamlBlock = match.group(1) ?? '';
    final body = raw.substring(match.end);
    final parsed = loadYaml(yamlBlock);
    final fm = <String, String>{};
    if (parsed is YamlMap) {
      parsed.forEach((k, v) => fm[k.toString()] = v.toString());
    }
    return _MarkdownDoc(frontmatter: fm, body: body);
  }
}
