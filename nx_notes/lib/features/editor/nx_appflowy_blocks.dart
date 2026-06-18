import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/features/editor/nx_document_link.dart';
import 'package:nx_notes/features/editor/nx_excalidraw_frame.dart';
import 'package:provider/provider.dart';

part 'nx_slash_menu.dart';
part 'nx_toggle_block.dart';
part 'nx_kgql_link_block.dart';
part 'nx_drag_to_reorder.dart';
part 'nx_excalidraw_block.dart';

const String nxToggleBlockType = 'nx_toggle';
const String nxBlogLinkBlockType = 'nx_blog_link';
const String nxExcalidrawBlockType = 'nx_excalidraw';

Map<String, BlockComponentBuilder> nxBlockComponentBuilders() {
  final builders = <String, BlockComponentBuilder>{
    ...standardBlockComponentBuilderMap,
    nxToggleBlockType: NxToggleBlockComponentBuilder(),
    nxBlogLinkBlockType: NxBlogLinkBlockComponentBuilder(),
    nxExcalidrawBlockType: NxExcalidrawBlockComponentBuilder(),
  };
  for (final entry in builders.entries) {
    if (entry.key == PageBlockKeys.type) {
      continue;
    }
    final builder = entry.value;
    builder.showActions = (_) => true;
    builder.actionBuilder = (context, _) {
      return NxDragToReorderAction(
        blockComponentContext: context,
        builder: builder,
      );
    };
  }
  return builders;
}

String nxPlainTextForCustomNode(Node node) {
  switch (node.type) {
    case nxToggleBlockType:
      final title = node.delta?.toPlainText().trim().isNotEmpty == true
          ? node.delta!.toPlainText().trim()
          : _stringAttribute(node, 'title', 'Toggle heading');
      return title;
    case nxBlogLinkBlockType:
      final title = _stringAttribute(node, 'title', 'Blog document');
      return 'Blog: $title';
    case nxExcalidrawBlockType:
      return _stringAttribute(node, 'title', 'Excalidraw');
    default:
      return '';
  }
}

bool _replaceCurrentParagraph(EditorState editorState, Node node) {
  return node.type == ParagraphBlockKeys.type &&
      (node.delta?.toPlainText().trim().isEmpty ?? false);
}

String _stringAttribute(Node node, String key, String fallback) {
  final value = node.attributes[key];
  return value is String ? value : fallback;
}

bool _boolAttribute(Node node, String key, bool fallback) {
  final value = node.attributes[key];
  return value is bool ? value : fallback;
}

Widget _wrapBlockSelection({
  required Node node,
  required SelectableMixin delegate,
  required EditorState editorState,
  required Widget child,
}) {
  return BlockSelectionContainer(
    node: node,
    delegate: delegate,
    listenable: editorState.selectionNotifier,
    remoteSelection: editorState.remoteSelections,
    blockColor: editorState.editorStyle.selectionColor,
    supportTypes: const <BlockSelectionType>[BlockSelectionType.block],
    child: child,
  );
}
