import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:nx_canvas_core/canvas_client.dart';
import 'package:flutter/foundation.dart';
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
    this.client = const MethodChannelCanvasClient(),
  });
  final EditorState editor;
  final String documentId;
  final Future<void> Function() persist;
  final CanvasClient client;
  void _diagnostic(String stage, String phase, {int? elapsedUs}) {
    final data = <String, Object>{
      'stage': stage,
      'phase': phase,
      'dart_time_ms': DateTime.now().millisecondsSinceEpoch,
      if (elapsedUs != null) 'duration_us': elapsedUs,
    };
    debugPrint('[NxCanvasDiagDart] ${jsonEncode(data)}');
    unawaited(client.diagnostic(data).catchError((Object _) {}));
  }

  Future<T> _measure<T>(String stage, Future<T> Function() work) async {
    final clock = Stopwatch()..start();
    _diagnostic(stage, 'begin');
    try {
      return await work();
    } finally {
      _diagnostic(stage, 'end', elapsedUs: clock.elapsedMicroseconds);
    }
  }

  bool _busy = false;
  String identity(Node node) =>
      jsonEncode([documentId, node.attributes['canvas_id']]);

  Future<bool> recover(Node node) async {
    if (_busy) return false;
    _busy = true;
    try {
      final pending = await client.recover();
      if (pending == null || pending.sessionId != identity(node)) {
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
      if (!await client.available()) {
        throw StateError(
          'Handwriting is available on the supported ink tablet. This drawing can still be viewed here.',
        );
      }
      final pending = await client.recover();
      if (pending != null) {
        if (pending.sessionId != identity(node)) {
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
      await _measure("docs.persist", persist);
      // Native recovery checkpoints every completed edit on its save worker.
      // Keep AppFlowy updates and document serialization out of live handwriting.
      var previousTick = DateTime.now().millisecondsSinceEpoch;
      final heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _diagnostic(
          'dart.heartbeat',
          'sample',
          elapsedUs: (now - previousTick - 5000) * 1000,
        );
        previousTick = now;
      });
      CanvasSavedDrawing? value;
      try {
        value = await client.open(
          CanvasOpenRequest(
            drawing: canvasDrawing(node),
            sessionId: identity(node),
            title: node.attributes['title'] as String? ?? 'Canvas',
            backLabel: '‹ Document',
          ),
        );
      } finally {
        heartbeat.cancel();
      }
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

  Future<void> _save(Node node, CanvasSavedDrawing value) async {
    _ensureEditable(node);
    if (value.sessionId != identity(node) || node.parent == null) {
      throw StateError(
        'The canvas changed while it was open. Its recovery copy has been kept.',
      );
    }
    final drawing = value.drawing;
    final token = value.token;
    await _measure(
      'docs.apply_drawing',
      () => editor.apply(
        editor.transaction..updateNode(node, {
          'drawing': drawing.toJson(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      ),
    );
    await _measure("docs.persist", persist);
    if (!await client.acknowledge(token)) {
      throw StateError('A newer canvas recovery copy is waiting to be saved.');
    }
  }
}
