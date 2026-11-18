import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Haptics that follow the platform (Spec #186 Req 21): iOS gives a light
/// selection tick when a choice changes; Android and the rest use the
/// platform's own tap feedback. The web has none.
void cpSelectionFeedback(BuildContext context) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
      HapticFeedback.selectionClick();
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      Feedback.forTap(context);
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      break;
  }
}
