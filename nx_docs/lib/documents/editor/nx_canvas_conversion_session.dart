import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:nx_docs/documents/editor/canvas_conversion_service.dart';
import 'package:nx_docs/documents/editor/nx_canvas_session.dart';

String canvasConversionFingerprint(Object? value) {
  Object? canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(v[key])};
    }
    if (v is List) return v.map(canonical).toList();
    if (v is num && v.isFinite && v == v.roundToDouble()) return v.toInt();
    return v;
  }

  return sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
}

class NxCanvasConversionSession {
  NxCanvasConversionSession({
    required this.editor,
    required this.persist,
    required this.convert,
    required this.isActive,
  });
  final EditorState editor;
  final Future<void> Function() persist;
  final ConvertCanvas convert;
  final bool Function() isActive;
  bool pendingSave = false;
  bool _busy = false;
  List<String> warnings = [];

  void _check(Node node) {
    if (!isActive() ||
        editor.isDisposed ||
        !editor.editable ||
        node.parent == null ||
        !identical(editor.getNodeAtPath(node.path), node)) {
      throw StateError('Document or canvas changed. Nothing new was inserted.');
    }
  }

  int _identityCount(String id) {
    int count(Node n) =>
        (n.type == nxCanvasBlockType && n.attributes['canvas_id'] == id
            ? 1
            : 0) +
        n.children.fold<int>(0, (sum, n) => sum + count(n));
    return count(editor.document.root);
  }

  Future<String> run(Node node) async {
    if (_busy) return 'Conversion is already running.';
    _busy = true;
    try {
      _check(node);
      if (pendingSave) {
        await persist();
        pendingSave = false;
        return 'Converted text saved.';
      }
      var id = node.attributes['canvas_id'];
      if (id is! String || id.isEmpty || _identityCount(id) != 1) {
        id = newCanvasId();
        await editor.apply(
          editor.transaction..updateNode(node, {'canvas_id': id}),
          options: const ApplyOptions(inMemoryUpdate: true),
        );
      }
      final canvasId = id;
      final drawing = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(node.attributes['drawing'])) as Map,
      );
      final fingerprint = canvasConversionFingerprint(drawing);
      if (node.attributes['converted_drawing_hash'] == fingerprint) {
        return 'This drawing is already converted.';
      }
      if (canvasDrawing(node).strokes.isEmpty) {
        throw StateError('Draw something on the canvas first.');
      }
      await persist();
      _check(node);
      final proposal = await convert(canvasId, drawing);
      _check(node);
      if (_identityCount(canvasId) != 1 ||
          node.attributes['canvas_id'] != canvasId ||
          canvasConversionFingerprint(node.attributes['drawing']) !=
              fingerprint) {
        throw StateError('Canvas changed during conversion. Please try again.');
      }
      final blocks = proposal.blocks
          .map((b) => Node.fromJson(Map<String, Object>.from(b)))
          .toList();
      final path = [...node.path];
      path[path.length - 1]++;
      await editor.apply(
        editor.transaction
          ..insertNodes(path, blocks)
          ..updateNode(node, {'converted_drawing_hash': fingerprint}),
        options: const ApplyOptions(inMemoryUpdate: true),
      );
      warnings = proposal.warnings;
      pendingSave = true;
      await persist();
      pendingSave = false;
      return 'Converted text added below the canvas.';
    } finally {
      _busy = false;
    }
  }
}
