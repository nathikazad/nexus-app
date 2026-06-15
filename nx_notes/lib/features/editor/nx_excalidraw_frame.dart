import 'package:flutter/widgets.dart';

import 'package:nx_notes/features/editor/nx_excalidraw_frame_stub.dart'
    if (dart.library.html) 'package:nx_notes/features/editor/nx_excalidraw_frame_web.dart';

class NxExcalidrawEditorFrame extends StatelessWidget {
  const NxExcalidrawEditorFrame({
    required this.scene,
    required this.onSave,
    required this.saveRequest,
    super.key,
  });

  final Map<String, dynamic> scene;
  final ValueChanged<Map<String, dynamic>> onSave;
  final int saveRequest;

  @override
  Widget build(BuildContext context) {
    return buildNxExcalidrawFrame(
      scene: scene,
      onSave: onSave,
      saveRequest: saveRequest,
    );
  }
}
