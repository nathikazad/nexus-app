import 'package:flutter/material.dart';

/// Covers file retrieval and source resolution without changing navigation.
/// The reader owns its own loading state after it opens.
VoidCallback showBookOpeningIndicator(BuildContext context) {
  final overlay = OverlayEntry(
    builder: (_) => const Stack(
      children: [
        ModalBarrier(dismissible: false, color: Color(0x33000000)),
        Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(semanticsLabel: 'Opening book'),
            ),
          ),
        ),
      ],
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(overlay);
  var closed = false;
  return () {
    if (closed) return;
    closed = true;
    overlay.remove();
    overlay.dispose();
  };
}
