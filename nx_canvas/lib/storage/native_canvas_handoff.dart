import 'package:flutter/services.dart';
import '../canvas/canvas_controller.dart';
import '../canvas/canvas_painter.dart';
import '../canvas/drawing.dart';
import 'canvas_store.dart';

/// Saves a native editor result to its own drawing before acknowledging recovery.
class NativeCanvasHandoff {
  NativeCanvasHandoff(
    this.store, {
    this.channel = const MethodChannel('nx_canvas/editor'),
  });
  final CanvasStore store;
  final MethodChannel channel;
  Future<void> save(dynamic value) async {
    if (value == null) return;
    final result = Map<String, dynamic>.from(value as Map);
    final drawing = Drawing.fromJson(
      Map<String, dynamic>.from(result['drawing'] as Map),
    );
    await store.saveCanvas(
      result['documentId'] as String,
      result['title'] as String,
      drawing,
      await renderPreview(drawing),
    );
    final acknowledged = await channel.invokeMethod<bool>(
      'ackDocument',
      result['saveToken'],
    );
    if (acknowledged != true) {
      throw StateError('A newer recovery copy is waiting. Please retry.');
    }
  }

  Future<void> recover() async {
    // Migrate the previous one-canvas handwriting trial without dropping ink.
    final legacy = await channel.invokeListMethod<dynamic>('recover') ?? [];
    if (legacy.isNotEmpty) {
      final c = CanvasController(await store.load());
      for (final item in legacy) {
        final data = Map<String, dynamic>.from(item as Map);
        c.addNativeStroke(
          (data['points'] as List).map(Dot.fromJson).toList(),
          color: data['color'] as int,
          width: (data['width'] as num).toDouble(),
          sourceId: data['id'] as String,
        );
      }
      await store.saveCanvas(
        'prototype',
        'First canvas',
        c.drawing,
        await renderPreview(c.drawing),
      );
      c.dispose();
      await channel.invokeMethod<void>('ack');
    }
    await save(await channel.invokeMethod<dynamic>('recoverDocument'));
  }
}
