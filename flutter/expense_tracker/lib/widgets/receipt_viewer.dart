import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a receipt image in a dialog sized to the viewport.
///
/// The image is constrained and zoomable rather than laid out at its natural
/// size: a tall receipt in an unconstrained Column overflows, which is exactly
/// what the earlier prototype did.
void showReceipt(BuildContext context, String imageUrl) {
  showDialog<void>(
    context: context,
    builder: (context) => _ReceiptDialog(imageUrl: imageUrl),
  );
}

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.height * 0.85,
          maxWidth: media.width * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible + BoxFit.contain is what keeps a portrait receipt inside
            // the dialog instead of overflowing it.
            Flexible(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    final expected = progress.expectedTotalBytes;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: expected == null
                              ? null
                              : progress.cumulativeBytesLoaded / expected,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'This receipt could not be loaded.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
