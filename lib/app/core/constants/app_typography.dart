import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_type.dart';

/// The old type helper, kept only so unmigrated screens compile; it now
/// forwards to [CpType] (Spec #186 Req 15). New code reads `context.cp.type`.
/// Deleted when the last screen moves (#208).
@Deprecated('Use context.cp.type (lib/app/core/design/).')
abstract final class AppTypography {
  /// Large tabular figures for money and balances.
  static TextStyle numberDisplay({Color? color}) =>
      CpType.standard.number.copyWith(color: color);
}
