import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

enum CpAvatarSize { small, medium, large }

/// A person's initials in an accent-tinted circle. Someone with no name
/// (an unnamed entry) shows a plain person icon instead.
class CpAvatar extends StatelessWidget {
  const CpAvatar({
    super.key,
    required this.name,
    this.size = CpAvatarSize.medium,
    this.semanticLabel,
  });

  final String name;
  final CpAvatarSize size;

  /// Read instead of [name], for example "Unnamed person".
  final String? semanticLabel;

  /// Up to two initials: the first letters of the first and last words.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final side = _side(context, size);
    final initials = initialsOf(name);
    return Semantics(
      label: semanticLabel ?? name,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: initials.isEmpty ? cp.colors.border : cp.colors.accentSoft,
          shape: BoxShape.circle,
        ),
        child: initials.isEmpty
            ? Icon(
                CpIcons.member,
                size: side * 0.45,
                color: cp.colors.textMuted,
              )
            : Text(
                initials,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: cp.type.labelMedium.copyWith(
                  color: cp.colors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: side * 0.35,
                ),
              ),
      ),
    );
  }

  static double _side(BuildContext context, CpAvatarSize size) {
    final sizes = context.cp.sizes;
    return switch (size) {
      CpAvatarSize.small => sizes.avatarSm,
      CpAvatarSize.medium => sizes.avatarMd,
      CpAvatarSize.large => sizes.avatarLg,
    };
  }
}

/// A few overlapping avatars with a "+N" count for the rest, such as the
/// people attending an event.
class CpAvatarStack extends StatelessWidget {
  const CpAvatarStack({
    super.key,
    required this.names,
    required this.semanticLabel,
    this.max = 4,
    this.size = CpAvatarSize.small,
  });

  final List<String> names;

  /// What the stack stands for, such as "148 attending".
  final String semanticLabel;
  final int max;
  final CpAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final shown = names.take(max).toList();
    final rest = names.length - shown.length;
    final ring = cp.sizes.avatarRing;
    Widget ringed(Widget child) => Container(
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        color: cp.colors.background,
        shape: BoxShape.circle,
      ),
      child: child,
    );
    final side = CpAvatar._side(context, size);
    final ringedSide = side + 2 * ring;
    final step = ringedSide - cp.sizes.avatarOverlap;
    final count = shown.length + (rest > 0 ? 1 : 0);
    final more = Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cp.colors.fill, shape: BoxShape.circle),
      child: Text(
        '+$rest',
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: cp.type.labelSmall.copyWith(
          color: cp.colors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: count == 0 ? 0 : ringedSide + step * (count - 1),
        height: ringedSide,
        child: Stack(
          children: [
            // Later avatars tuck under earlier ones, so paint them first.
            for (var i = count - 1; i >= 0; i--)
              Positioned(
                left: step * i,
                child: ringed(
                  i < shown.length
                      ? CpAvatar(name: shown[i], size: size)
                      : more,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
