import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:nx_canvas_core/canvas_client.dart';
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

/// Read only the stored block tree, never the live editor or stroke payloads.
/// A generated ID in memory alone is not proof that recovery can find its block.
bool hasPersistedCanvasIdentity(Map<String, dynamic> json, String id) {
  int count(dynamic node) {
    if (node is! Map) return 0;
    final attributes = node['data'];
    final own =
        node['type'] == nxCanvasBlockType &&
            attributes is Map &&
            attributes['canvas_id'] == id
        ? 1
        : 0;
    final children = node['children'];
    return own +
        (children is List
            ? children.fold<int>(0, (sum, child) => sum + count(child))
            : 0);
  }

  return id.isNotEmpty && count(json['document']) == 1;
}

/// Acknowledges the native recovery file only after the host document is saved.
class NxCanvasSession {
  NxCanvasSession({
    required this.editor,
    required this.documentId,
    required this.persist,
    this.client = const MethodChannelCanvasClient(),
    this.isIdentityPersisted,
  });
  final EditorState editor;
  final String documentId;
  final Future<void> Function() persist;
  final CanvasClient client;

  /// Host confirms the ID exists uniquely in its durable document snapshot.
  /// Unknown hosts retain the conservative save-before-open behavior.
  final bool Function(String id)? isIdentityPersisted;
  String? _traceId;
  int? _returnTappedAtMs;
  void reportReturnFrame() {
    final tapped = _returnTappedAtMs;
    if (tapped == null) return;
    _diagnostic(
      'transition.return.frame',
      'end',
      elapsedUs: (DateTime.now().millisecondsSinceEpoch - tapped) * 1000,
    );
    _returnTappedAtMs = null;
  }

  void _diagnostic(String stage, String phase, {int? elapsedUs}) {
    final data = <String, Object>{
      'stage': stage,
      if (_traceId != null) 'trace_id': _traceId!,
      'phase': phase,
      'dart_time_ms': DateTime.now().millisecondsSinceEpoch,
      if (elapsedUs != null) 'duration_us': elapsedUs,
    };
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
      final pending = await _measure('docs.recover', client.recover);
      if (pending == null || pending.sessionId != identity(node)) {
        return false;
      }
      _ensureUnambiguousRecovery(node);
      await _save(node, pending);
      return true;
    } finally {
      _busy = false;
    }
  }

  Future<void> open(Node node) async {
    if (_busy) return;
    _busy = true;
    final tappedAt = DateTime.now().millisecondsSinceEpoch;
    _traceId = newCanvasId();
    _diagnostic('transition.open.tap', 'begin');
    try {
      _ensureEditable(node);
      if (!await _measure('docs.available', client.available)) {
        throw StateError(
          'Handwriting is available on the supported ink tablet. This drawing can still be viewed here.',
        );
      }
      final pending = await _measure('docs.recover', client.recover);
      if (pending != null) {
        if (pending.sessionId != identity(node)) {
          throw StateError(
            'Another canvas has unsaved changes. Open its document and canvas first to recover them.',
          );
        }
        _ensureUnambiguousRecovery(node);
        await _save(node, pending);
      }
      // Preserve a durable identity; only new/duplicated blocks need a new one.
      final id = node.attributes['canvas_id'];
      if (id is! String || id.isEmpty || _identityCount(id) > 1) {
        await _measure(
          'docs.prepare_identity',
          () => editor.apply(
            editor.transaction..updateNode(node, {'canvas_id': newCanvasId()}),
            options: const ApplyOptions(inMemoryUpdate: true),
          ),
        );
      }
      final canvasId = node.attributes['canvas_id'] as String;
      if (isIdentityPersisted?.call(canvasId) != true) {
        await _measure('docs.persist_identity', persist);
      }
      _ensureEditable(node);
      // Existing identities leave the host autosave timer/in-flight save alone.
      // Native recovery checkpoints every completed edit on its save worker.
      // Keep AppFlowy updates and document serialization out of live handwriting.
      final drawing = await _measure(
        'docs.decode_open_drawing',
        () async => canvasDrawing(node),
      );
      _diagnostic(
        'transition.open.send',
        'mark',
        elapsedUs: (DateTime.now().millisecondsSinceEpoch - tappedAt) * 1000,
      );
      final value = await client.open(
        CanvasOpenRequest(
          drawing: drawing,
          sessionId: identity(node),
          title: node.attributes['title'] as String? ?? 'Canvas',
          backLabel: '‹ Document',
          traceId: _traceId,
          openTappedAtMs: tappedAt,
        ),
      );
      _returnTappedAtMs = value?.returnTappedAtMs;
      _traceId = value?.traceId ?? _traceId;

      if (value != null) await _save(node, value);
      if (_returnTappedAtMs != null) {
        _diagnostic(
          'transition.return.saved',
          'mark',
          elapsedUs:
              (DateTime.now().millisecondsSinceEpoch - _returnTappedAtMs!) *
              1000,
        );
      }
    } catch (_) {
      _diagnostic('transition.error', 'error');
      rethrow;
    } finally {
      _busy = false;
    }
  }

  void _ensureUnambiguousRecovery(Node node) {
    final id = node.attributes['canvas_id'];
    if (id is String && _identityCount(id) > 1) {
      throw StateError(
        'Duplicate canvas identities make recovery ambiguous. The recovery copy has been kept.',
      );
    }
  }

  int _identityCount(String id) {
    int count(Node n) =>
        (n.type == nxCanvasBlockType && n.attributes['canvas_id'] == id
            ? 1
            : 0) +
        n.children.fold<int>(0, (sum, child) => sum + count(child));
    return count(editor.document.root);
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
    if (!value.unchanged) {
      await _measure(
        'docs.apply_drawing',
        () => editor.apply(
          editor.transaction..updateNode(node, {
            'drawing': drawing.toJson(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
          // This session explicitly persists below; avoid the host's duplicate save.
          options: const ApplyOptions(inMemoryUpdate: true),
        ),
      );
      await _measure("docs.persist", persist);
    }
    if (!await _measure('docs.acknowledge', () => client.acknowledge(token))) {
      throw StateError('A newer canvas recovery copy is waiting to be saved.');
    }
  }
}
