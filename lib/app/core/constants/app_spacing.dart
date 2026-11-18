import 'package:crewpoint_app/app/core/design/tokens/scale.dart';

/// The old spacing names, kept only so unmigrated screens compile; each now
/// forwards to the design tokens (Spec #186 Req 15). New code reads
/// `context.cp.space`. Deleted when the last screen moves (#208).
@Deprecated('Use context.cp.space (lib/app/core/design/).')
abstract final class AppSpacing {
  static const double xs = CpScale.space4;
  static const double sm = CpScale.space8;
  static const double md = CpScale.space12;
  static const double lg = CpScale.space16;
  static const double xl = CpScale.space24;
  static const double xxl = CpScale.space32;
  static const double xxxl = CpScale.space48;
}
