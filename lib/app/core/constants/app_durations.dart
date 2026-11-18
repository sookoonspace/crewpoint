import 'package:crewpoint_app/app/core/design/tokens/scale.dart';

/// The old duration names, kept only so unmigrated code compiles; each now
/// forwards to the design tokens (Spec #186 Req 15). New code reads
/// `context.cp.motion`. Deleted when the last screen moves (#208).
@Deprecated('Use context.cp.motion (lib/app/core/design/).')
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: CpScale.motionFast);
  static const Duration medium = Duration(milliseconds: CpScale.motionMedium);
  static const Duration slow = Duration(milliseconds: CpScale.motionSlow);
  static const Duration snackbar = Duration(seconds: CpScale.snackbarSeconds);
}
