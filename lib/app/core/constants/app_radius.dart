import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/scale.dart';

/// The old radius names, kept only so unmigrated screens compile; each now
/// forwards to the design tokens (Spec #186 Req 15). New code reads
/// `context.cp.radii`. Deleted when the last screen moves (#208).
@Deprecated('Use context.cp.radii (lib/app/core/design/).')
abstract final class AppRadius {
  static const double sm = CpScale.radius4;
  static const double md = CpScale.radius8;
  static const double lg = CpScale.radius12;
  static const double xl = CpScale.radius16;
  static const double xxl = CpScale.radius24;
  static const double pill = CpScale.radiusPill;

  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius borderPill = BorderRadius.all(
    Radius.circular(pill),
  );
}
