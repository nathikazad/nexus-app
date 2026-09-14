import 'dart:convert';
import 'dart:math';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';
import 'package:nx_canvas_core/drawing.dart';

const nxCanvasBlockType = 'nx_canvas';
String newCanvasId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

Node nxCanvasNode() => Node(
  type: nxCanvasBlockType,
  attributes: {
    'title': 'Canvas',
    'canvas_id': newCanvasId(),
    'drawing': Drawing().toJson(),
    'preview_height': 280.0,
  },
);

Drawing canvasDrawing(Node node) => Drawing.fromJson(
  Map<String, dynamic>.from(node.attributes['drawing'] as Map),
);

/// Acknowledges the native recovery file only after the host document is saved.
class NxCanvasSession {
  NxCanvasSession({
    required this.editor,
    required this.documentId,
    required this.persist,
    this.channel = const MethodChannel('nx_docs/canvas'),
  });
  final EditorState editor;
  final String documentId;
  final Future<void> Function() persist;
  final MethodChannel channel;
  bool _busy = false;
  String identity(Node node) =>
      jsonEncode([documentId, node.attributes['canvas_id']]);

  Future<bool> recover(Node node) async {
    if (_busy) return false;
    _busy = true;
    try {
      final pending = await channel.invokeMapMethod<String, dynamic>(
        'recoverDocument',
      );
      if (pending == null || pending['documentId'] != identity(node)) {
        return false;
      }
      await _save(node, pending);
      return true;
    } finally {
      _busy = false;
    }
  }

  Future<void> open(Node node) async {
    if (_busy) return;
    _busy = true;
    try {
      _ensureEditable(node);
      if (await channel.invokeMethod<bool>('available') != true) {
        throw StateError(
          'Handwriting is available on the supported ink tablet. This drawing can still be viewed here.',
        );
      }
      final pending = await channel.invokeMapMethod<String, dynamic>(
        'recoverDocument',
      );
      if (pending != null) {
        if (pending['documentId'] != identity(node)) {
          throw StateError(
            'Another canvas has unsaved changes. Open its document and canvas first to recover them.',
          );
        }
        await _save(node, pending);
      }
      // A new session identity also makes copied blocks independent.
      await editor.apply(
        editor.transaction..updateNode(node, {'canvas_id': newCanvasId()}),
      );
      await persist();
      final value = await channel
          .invokeMapMethod<String, dynamic>('openDocument', {
            ...canvasDrawing(node).toJson(),
            'documentId': identity(node),
            'title': node.attributes['title'] ?? 'Canvas',
            'backLabel': '‹ Document',
          });
      if (value != null) await _save(node, value);
    } finally {
      _busy = false;
    }
  }

  void _ensureEditable(Node node) {
    if (editor.isDisposed ||
        !editor.editable ||
        node.parent == null ||
        !identical(editor.getNodeAtPath(node.path), node)) {
      throw StateError(
        'Document is no longer editable; canvas recovery has been kept.',
      );
    }
  }

  Future<void> _save(Node node, Map<String, dynamic> value) async {
    _ensureEditable(node);
    if (value['documentId'] != identity(node) || node.parent == null) {
      throw StateError(
        'The canvas changed while it was open. Its recovery copy has been kept.',
      );
    }
    final drawing = Drawing.fromJson(
      Map<String, dynamic>.from(value['drawing'] as Map),
    );
    final token = value['saveToken'];
    if (token is! String) {
      throw const FormatException('Missing canvas save token');
    }
    await editor.apply(
      editor.transaction..updateNode(node, {
        'drawing': drawing.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    await persist();
    if (await channel.invokeMethod<bool>('ackDocument', token) != true) {
      throw StateError('A newer canvas recovery copy is waiting to be saved.');
    }
  }
}
