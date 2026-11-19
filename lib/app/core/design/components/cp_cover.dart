import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// An event's cover banner (Spec #186 Req 43, 44): its photo, or without
/// one a calm accent banner with the event's icon and an optional label.
/// No stock or per-template photos.
class CpCoverBanner extends StatelessWidget {
  const CpCoverBanner({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.image,
    this.label,
    this.height,
  });

  /// The photo, or null for the fallback banner.
  final ImageProvider? image;
  final IconData icon;

  /// Shown on the fallback banner, such as the template's name.
  final String? label;

  /// Read by screen readers, such as "Cover photo".
  final String semanticLabel;

  /// Defaults to the phone banner height.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: cp.radii.lg,
        child: SizedBox(
          height: height ?? cp.sizes.coverBanner,
          width: double.infinity,
          child: image != null
              ? Image(
                  key: const Key('cover.photo'),
                  image: image!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) =>
                      _Fallback(icon: icon, label: label),
                )
              : _Fallback(icon: icon, label: label),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return ColoredBox(
      key: const Key('cover.fallback'),
      color: cp.colors.banner,
      child: Padding(
        padding: EdgeInsets.all(cp.space.lg),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                icon,
                size: cp.sizes.coverIcon,
                color: cp.colors.onBanner.withValues(alpha: 0.9),
              ),
            ),
            if (label != null)
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cp.type.labelMedium.copyWith(
                    color: cp.colors.onBanner,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// An event's cover as a small square on its list card: the photo, or the
/// event's icon on the accent tint.
class CpCoverThumb extends StatelessWidget {
  const CpCoverThumb({super.key, required this.icon, this.image, this.size});

  final ImageProvider? image;
  final IconData icon;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final side = size ?? cp.sizes.coverThumb;
    final fallback = ColoredBox(
      key: const Key('cover.thumbFallback'),
      color: cp.colors.accentSoft,
      child: Center(
        child: Icon(icon, size: side * 0.42, color: cp.colors.accent),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: cp.radii.md,
        child: SizedBox.square(
          dimension: side,
          child: image == null
              ? fallback
              : Image(
                  key: const Key('cover.thumb'),
                  image: image!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
