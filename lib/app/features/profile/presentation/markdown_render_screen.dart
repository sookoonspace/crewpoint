import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

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
        SnackBar(content: Text('Could not open ${widget.hostedUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: FutureBuilder<_MarkdownDoc?>(
        future: _doc,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
    final stamps = <Widget>[];
    final effective = doc.frontmatter['effective_date'];
    final updated = doc.frontmatter['last_updated'];
    if (effective != null) {
      stamps.add(
        _StampLine(
          key: const Key('legal.stamp.effective'),
          label: 'Effective',
          value: effective,
        ),
      );
    }
    if (updated != null) {
      stamps.add(
        _StampLine(
          key: const Key('legal.stamp.lastUpdated'),
          label: 'Last updated',
          value: updated,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        if (stamps.isNotEmpty) ...[
          ...stamps,
          const SizedBox(height: AppSpacing.lg),
        ],
        MarkdownBody(key: const Key('legal.markdown.body'), data: doc.body),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          key: const Key('legal.viewHosted'),
          onPressed: onLaunchHosted,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('View hosted version'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.darkGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: AppColors.charcoal),
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.mediumGrey),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load this document right now.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('legal.fallback.viewOnline'),
              onPressed: onLaunch,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View online'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hostedUrl,
              style: const TextStyle(color: AppColors.mediumGrey, fontSize: 12),
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
