import 'package:flutter/material.dart';

Widget buildNxExcalidrawFrame({
  required Map<String, dynamic> scene,
  required ValueChanged<Map<String, dynamic>> onSave,
  required int saveRequest,
}) {
  return const Center(
    child: Text(
      'Excalidraw editing is available in the web build.',
      style: TextStyle(fontSize: 13),
    ),
  );
}
