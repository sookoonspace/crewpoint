import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/palette.dart';
import 'package:crewpoint_app/app/core/design/tokens/scale.dart';

/// Spacing tokens, read with `context.cp.space`.
@immutable
class CpSpacing extends ThemeExtension<CpSpacing> {
  const CpSpacing();

  double get xs => CpScale.space4;
  double get sm => CpScale.space8;
  double get md => CpScale.space12;
  double get lg => CpScale.space16;
  double get xl => CpScale.space24;
  double get xxl => CpScale.space32;
  double get xxxl => CpScale.space48;

  @override
  CpSpacing copyWith() => this;

  @override
  CpSpacing lerp(covariant CpSpacing? other, double t) => this;
}

/// Corner radius tokens, read with `context.cp.radii`.
@immutable
class CpRadii extends ThemeExtension<CpRadii> {
  const CpRadii();

  /// Small marks and progress bars.
  BorderRadius get xs =>
      const BorderRadius.all(Radius.circular(CpScale.radius4));

  /// Fields, icon tiles and small buttons.
  BorderRadius get sm =>
      const BorderRadius.all(Radius.circular(CpScale.radius8));

  /// Cards, rows and buttons.
  BorderRadius get md =>
      const BorderRadius.all(Radius.circular(CpScale.radius12));

  /// Banners and sheets.
  BorderRadius get lg =>
      const BorderRadius.all(Radius.circular(CpScale.radius16));
  BorderRadius get xl =>
      const BorderRadius.all(Radius.circular(CpScale.radius24));

  /// Chips, badges and pill buttons.
  BorderRadius get pill =>
      const BorderRadius.all(Radius.circular(CpScale.radiusPill));

  @override
  CpRadii copyWith() => this;

  @override
  CpRadii lerp(covariant CpRadii? other, double t) => this;
}

/// Size tokens (icons, avatars, tap targets), read with `context.cp.sizes`.
@immutable
class CpSizes extends ThemeExtension<CpSizes> {
  const CpSizes();

  double get iconXs => CpScale.icon14;
  double get iconSm => CpScale.icon16;
  double get iconMd => CpScale.icon20;
  double get iconLg => CpScale.icon24;
  double get iconXl => CpScale.icon32;
  double get iconHero => CpScale.icon64;

  /// The smallest tap target.
  double get tapMin => CpScale.tapMin;

  double get avatarSm => CpScale.avatar32;
  double get avatarMd => CpScale.avatar40;
  double get avatarLg => CpScale.avatar64;

  /// The ring around a stacked avatar, in the page colour.
  double get avatarRing => CpScale.avatarRing;

  /// How far each stacked avatar tucks under the one before.
  double get avatarOverlap => CpScale.avatarOverlap;
  double get ringSm => CpScale.ring40;
  double get ringLg => CpScale.ring52;
  double get ringStroke => CpScale.ringStroke;
  double get chipHeight => CpScale.chip28;
  double get rowMinHeight => CpScale.row60;
  double get topBarHeight => CpScale.topBar52;
  double get statMinHeight => CpScale.stat104;
  double get iconTile => CpScale.iconTile40;
  double get skeletonLine => CpScale.skeletonLine;
  double get hairline => CpScale.hairline;

  @override
  CpSizes copyWith() => this;

  @override
  CpSizes lerp(covariant CpSizes? other, double t) => this;
}

/// Motion tokens, read with `context.cp.motion`. Motion is short and subtle
/// (Spec #186 Req 20).
@immutable
class CpMotion extends ThemeExtension<CpMotion> {
  const CpMotion();

  /// Quick interactions: a chip toggle, a ripple.
  Duration get fast => const Duration(milliseconds: CpScale.motionFast);

  /// Standard transitions: a sheet opening.
  Duration get medium => const Duration(milliseconds: CpScale.motionMedium);

  /// Page transitions.
  Duration get slow => const Duration(milliseconds: CpScale.motionSlow);

  /// How long a snackbar stays.
  Duration get snackbar => const Duration(seconds: CpScale.snackbarSeconds);

  Curve get curve => Curves.easeOutCubic;

  @override
  CpMotion copyWith() => this;

  @override
  CpMotion lerp(covariant CpMotion? other, double t) => this;
}

/// Shadow tokens, read with `context.cp.shadows`. Cards rely on a border
/// and the faintest shadow; only floating things (menus, sheets) lift.
@immutable
class CpShadows extends ThemeExtension<CpShadows> {
  const CpShadows({required this.card, required this.raised});

  static const light = CpShadows(
    card: [
      BoxShadow(
        color: Color(CpPalette.lightShadowCard),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ],
    raised: [
      BoxShadow(
        color: Color(CpPalette.lightShadowRaised),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
  );

  static const dark = CpShadows(
    card: [],
    raised: [
      BoxShadow(
        color: Color(CpPalette.darkShadowRaised),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
  );

  final List<BoxShadow> card;
  final List<BoxShadow> raised;

  @override
  CpShadows copyWith({List<BoxShadow>? card, List<BoxShadow>? raised}) =>
      CpShadows(card: card ?? this.card, raised: raised ?? this.raised);

  @override
  CpShadows lerp(covariant CpShadows? other, double t) {
    if (other == null) return this;
    return CpShadows(
      card: BoxShadow.lerpList(card, other.card, t) ?? const [],
      raised: BoxShadow.lerpList(raised, other.raised, t) ?? const [],
    );
  }
}
