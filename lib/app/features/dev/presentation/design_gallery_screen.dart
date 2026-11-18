import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/gallery/design_gallery.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// The Design gallery (Spec #186 Req 17): every design-system component in
/// light, dark or 200% text. Dev build only, at
/// `/profile/dev-tools/design-gallery`. Its text is sample content, so it
/// is not translated.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  DesignGalleryVariant _variant = DesignGalleryVariant.light;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Scaffold(
      appBar: CpTopBar(
        title: 'Design gallery',
        leadingTooltip: 'Back',
        leadingKey: const Key('dev.gallery.back'),
        onLeading: () => context.pop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              cp.space.lg,
              cp.space.xs,
              cp.space.lg,
              cp.space.sm,
            ),
            child: SegmentedButton<DesignGalleryVariant>(
              key: const Key('dev.gallery.variant'),
              showSelectedIcon: false,
              segments: [
                for (final v in DesignGalleryVariant.values)
                  ButtonSegment(
                    value: v,
                    label: Text(v.label, key: Key('dev.gallery.${v.name}')),
                  ),
              ],
              selected: {_variant},
              onSelectionChanged: (s) => setState(() => _variant = s.first),
            ),
          ),
          Expanded(
            child: DesignGalleryFrame(
              variant: _variant,
              child: const SingleChildScrollView(child: DesignGallery()),
            ),
          ),
        ],
      ),
    );
  }
}
