import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// Full-screen receipt viewer, dark in both themes so the photo stands
/// out. Tap to close; pinch to zoom.
class ReceiptViewer extends StatelessWidget {
  const ReceiptViewer({super.key, required this.imageUrl});

  final String imageUrl;

  static Future<void> show({
    required BuildContext context,
    required String imageUrl,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReceiptViewer(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    const dark = CpColors.dark;
    return Theme(
      data: Theme.of(context).copyWith(extensions: [dark]),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: dark.background,
          appBar: CpTopBar(
            leadingIcon: CpIcons.actionClose,
            leadingKey: const Key('budget.receipt.viewer.close'),
            leadingTooltip: MaterialLocalizations.of(
              context,
            ).closeButtonTooltip,
            onLeading: () => Navigator.of(context).pop(),
          ),
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  key: const Key('budget.receipt.viewer.image'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    CpIcons.imageBroken,
                    color: dark.textMuted,
                    size: cp.sizes.iconHero,
                  ),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : CircularProgressIndicator(color: dark.accent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
