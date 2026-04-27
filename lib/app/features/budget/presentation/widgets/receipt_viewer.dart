import 'package:flutter/material.dart';

/// Full-screen receipt viewer. Tap-to-dismiss. Pinch-to-zoom via [InteractiveViewer].
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              key: const Key('budget.receipt.viewer.image'),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64,
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const CircularProgressIndicator();
              },
            ),
          ),
        ),
      ),
    );
  }
}
