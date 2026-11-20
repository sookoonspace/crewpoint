import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/palette.dart';

/// Colour tokens, read with `context.cp.colors`.
///
/// Light and dark differ only in these values. Exactly one accent; the
/// status colours (`done`, `due`, `overdue`) mean only done or paid, due,
/// and overdue, and always sit beside an icon (Spec #186 Req 10).
@immutable
class CpColors extends ThemeExtension<CpColors> {
  const CpColors({
    required this.background,
    required this.surface,
    required this.fill,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.banner,
    required this.onBanner,
    required this.done,
    required this.doneSoft,
    required this.due,
    required this.dueSoft,
    required this.overdue,
    required this.overdueSoft,
  });

  static const light = CpColors(
    background: Color(CpPalette.lightBackground),
    surface: Color(CpPalette.lightSurface),
    fill: Color(CpPalette.lightFill),
    border: Color(CpPalette.lightBorder),
    text: Color(CpPalette.lightText),
    textMuted: Color(CpPalette.lightTextMuted),
    accent: Color(CpPalette.lightAccent),
    accentSoft: Color(CpPalette.lightAccentSoft),
    onAccent: Color(CpPalette.lightOnAccent),
    banner: Color(CpPalette.lightBanner),
    onBanner: Color(CpPalette.lightOnBanner),
    done: Color(CpPalette.lightDone),
    doneSoft: Color(CpPalette.lightDoneSoft),
    due: Color(CpPalette.lightDue),
    dueSoft: Color(CpPalette.lightDueSoft),
    overdue: Color(CpPalette.lightOverdue),
    overdueSoft: Color(CpPalette.lightOverdueSoft),
  );

  static const dark = CpColors(
    background: Color(CpPalette.darkBackground),
    surface: Color(CpPalette.darkSurface),
    fill: Color(CpPalette.darkFill),
    border: Color(CpPalette.darkBorder),
    text: Color(CpPalette.darkText),
    textMuted: Color(CpPalette.darkTextMuted),
    accent: Color(CpPalette.darkAccent),
    accentSoft: Color(CpPalette.darkAccentSoft),
    onAccent: Color(CpPalette.darkOnAccent),
    banner: Color(CpPalette.darkBanner),
    onBanner: Color(CpPalette.darkOnBanner),
    done: Color(CpPalette.darkDone),
    doneSoft: Color(CpPalette.darkDoneSoft),
    due: Color(CpPalette.darkDue),
    dueSoft: Color(CpPalette.darkDueSoft),
    overdue: Color(CpPalette.darkOverdue),
    overdueSoft: Color(CpPalette.darkOverdueSoft),
  );

  /// The page behind cards.
  final Color background;

  /// Cards, sheets, bars and fields.
  final Color surface;

  /// A quiet tinted area inside a surface (a segmented control's track).
  final Color fill;

  /// Hairlines, card edges and field outlines.
  final Color border;
  final Color text;

  /// Secondary text and trailing icons.
  final Color textMuted;

  /// The one accent: primary buttons, links, selection.
  final Color accent;

  /// Accent tint behind accent text or icons (chips, icon tiles).
  final Color accentSoft;

  /// Text and icons on [accent].
  final Color onAccent;

  /// The Event home banner when an event has no cover photo.
  final Color banner;
  final Color onBanner;

  /// Done or paid.
  final Color done;
  final Color doneSoft;

  /// Due soon.
  final Color due;
  final Color dueSoft;

  /// Overdue, errors and destructive actions.
  final Color overdue;
  final Color overdueSoft;

  @override
  CpColors copyWith({
    Color? background,
    Color? surface,
    Color? fill,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? banner,
    Color? onBanner,
    Color? done,
    Color? doneSoft,
    Color? due,
    Color? dueSoft,
    Color? overdue,
    Color? overdueSoft,
  }) => CpColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    fill: fill ?? this.fill,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    onAccent: onAccent ?? this.onAccent,
    banner: banner ?? this.banner,
    onBanner: onBanner ?? this.onBanner,
    done: done ?? this.done,
    doneSoft: doneSoft ?? this.doneSoft,
    due: due ?? this.due,
    dueSoft: dueSoft ?? this.dueSoft,
    overdue: overdue ?? this.overdue,
    overdueSoft: overdueSoft ?? this.overdueSoft,
  );

  @override
  CpColors lerp(covariant CpColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return CpColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      fill: mix(fill, other.fill),
      border: mix(border, other.border),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      onAccent: mix(onAccent, other.onAccent),
      banner: mix(banner, other.banner),
      onBanner: mix(onBanner, other.onBanner),
      done: mix(done, other.done),
      doneSoft: mix(doneSoft, other.doneSoft),
      due: mix(due, other.due),
      dueSoft: mix(dueSoft, other.dueSoft),
      overdue: mix(overdue, other.overdue),
      overdueSoft: mix(overdueSoft, other.overdueSoft),
    );
  }
}

/// Colours that stay the same in light and dark, read directly.
abstract final class CpFixedColors {
  /// A QR code's modules and ground: dark on light in either theme, so it
  /// scans.
  static const Color qrInk = Color(CpPalette.qrInk);
  static const Color qrPaper = Color(CpPalette.qrPaper);
}
