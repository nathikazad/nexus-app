import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/editor/nx_document_link.dart';
import 'package:provider/provider.dart';

part 'highlight_note_dialog.dart';
part 'highlight_note_hover.dart';

const String nxHighlightNoteIdAttribute = 'nx_note_id';
const String nxHighlightNotesDocumentAttribute = 'nx_highlight_notes';
const String _defaultNoteHighlightColor = '0x4def4444';
const Color _inlineHoverBackground = Color(0xffffffff);
const Color _inlineHoverForeground = Color(0xff18181b);
const Color _inlineHoverMuted = Color(0xff71717a);
const Color _inlineHoverButtonBackground = Color(0xfff4f4f5);
const Color _inlineHoverDivider = Color(0x1f18181b);

void registerNxHighlightNoteAttribute() {
  if (!AppFlowyRichTextKeys.supportSliced.contains(
    nxHighlightNoteIdAttribute,
  )) {
    AppFlowyRichTextKeys.supportSliced.add(nxHighlightNoteIdAttribute);
  }
}

final ToolbarItem nxHighlightNoteToolbarItem = ToolbarItem(
  id: 'nx.highlightNote',
  group: 4,
  isActive: onlyShowInTextType,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection?.normalized;
    final hasNote =
        selection != null &&
        nxHighlightNoteIdInSelection(editorState, selection) != null;
    final disabled = selection == null || selection.isCollapsed;
    final effectiveIconColor = disabled
        ? Colors.white.withValues(alpha: 0.42)
        : Colors.white;
    final child = SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        padding: EdgeInsets.zero,
        tooltip: 'Note',
        icon: Icon(
          hasNote ? Icons.article : Icons.article_outlined,
          color: effectiveIconColor,
          size: 18,
        ),
        onPressed: disabled
            ? null
            : () {
                unawaited(
                  showNxHighlightNoteDialog(context, editorState, selection),
                );
              },
      ),
    );

    if (tooltipBuilder == null) {
      return child;
    }
    return tooltipBuilder(context, 'nx.highlightNote', 'Note', child);
  },
);

TextSpan nxHighlightNoteTextSpanDecorator(
  BuildContext context,
  Node node,
  int index,
  TextInsert text,
  TextSpan before,
  TextSpan after,
) {
  final attributes = text.attributes;
  final noteId = attributes?[nxHighlightNoteIdAttribute];
  final href = attributes?[AppFlowyRichTextKeys.href] as String?;
  if ((noteId is! String || noteId.trim().isEmpty) && href == null) {
    return defaultTextSpanDecoratorForAttribute(
      context,
      node,
      index,
      text,
      before,
      after,
    );
  }

  final editorState = context.read<EditorState>();
  final selection = Selection.single(
    path: node.path,
    startOffset: index,
    endOffset: index + text.text.length,
  );

  return TextSpan(
    text: text.text,
    style: after.style ?? before.style,
    mouseCursor: SystemMouseCursors.click,
    onEnter: (event) {
      final noteText = noteId is String
          ? nxHighlightNoteText(editorState, noteId)
          : null;
      if ((noteText == null || noteText.trim().isEmpty) && href == null) {
        return;
      }
      _NxInlineHoverOverlay.show(
        context: context,
        editorState: editorState,
        position: event.position,
        noteText: noteText,
        href: href,
        selection: selection,
      );
    },
    onExit: (_) => _NxInlineHoverOverlay.scheduleHide(),
    recognizer: TapGestureRecognizer()
      ..onTap = () {
        if (href != null) {
          unawaited(editorLaunchUrl(href));
          return;
        }
        if (noteId is! String) {
          return;
        }
        unawaited(
          showNxHighlightNoteDialog(
            context,
            editorState,
            selection,
            noteId: noteId,
          ),
        );
      },
  );
}

List<Widget> nxHighlightNoteOverlayBuilder(
  BuildContext context,
  Node node,
  SelectableMixin delegate,
) {
  final delta = node.delta;
  if (delta == null) {
    return const <Widget>[];
  }

  final editorState = context.read<EditorState>();
  final widgets = <Widget>[];
  var index = 0;
  for (final textInsert in delta.whereType<TextInsert>()) {
    final noteId = textInsert.attributes?[nxHighlightNoteIdAttribute];
    final href = textInsert.attributes?[AppFlowyRichTextKeys.href] as String?;
    final noteText = noteId is String && noteId.trim().isNotEmpty
        ? nxHighlightNoteText(editorState, noteId)
        : null;
    final hasNote = noteText != null && noteText.trim().isNotEmpty;
    if (hasNote || href != null) {
      final selection = Selection.single(
        path: node.path,
        startOffset: index,
        endOffset: index + textInsert.length,
      );
      final rects = delegate.getRectsInSelection(selection);
      for (final rect in rects) {
        widgets.add(
          Positioned.fromRect(
            rect: rect,
            child: _NxInlineHoverTarget(
              editorState: editorState,
              selection: selection,
              noteId: noteId is String ? noteId : null,
              noteText: noteText,
              href: href,
            ),
          ),
        );
      }
    }
    index += textInsert.length;
  }

  return widgets;
}

Future<void> showNxHighlightNoteDialog(
  BuildContext context,
  EditorState editorState,
  Selection selection, {
  String? noteId,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final normalized = selection.normalized;
  final effectiveNoteId =
      noteId ?? nxHighlightNoteIdInSelection(editorState, normalized);
  final initialText = effectiveNoteId == null
      ? ''
      : nxHighlightNoteText(editorState, effectiveNoteId) ?? '';
  final quote = editorState.getTextInSelection(normalized).join('\n').trim();
  _NxInlineHoverOverlay.hide();
  if (!editorState.editable) {
    if (!navigator.mounted) {
      return;
    }
    await _showNxHighlightNoteViewer(
      navigator.context,
      noteText: initialText,
      quote: quote,
    );
    return;
  }
  _suppressFloatingToolbar(editorState);
  if (!navigator.mounted) {
    return;
  }
  final result = await showDialog<_NxHighlightNoteDialogResult>(
    context: navigator.context,
    builder: (context) {
      return _NxHighlightNoteDialog(
        initialText: initialText,
        quote: quote,
        canDelete: effectiveNoteId != null,
      );
    },
  );
  if (result == null) {
    return;
  }

  switch (result.action) {
    case _NxHighlightNoteDialogAction.save:
      await _saveHighlightNote(
        editorState: editorState,
        selection: normalized,
        noteId: effectiveNoteId,
        text: result.text,
        quote: quote,
      );
    case _NxHighlightNoteDialogAction.delete:
      if (effectiveNoteId != null) {
        await _deleteHighlightNote(editorState, effectiveNoteId);
      }
  }
}

Future<void> _showNxHighlightNoteViewer(
  BuildContext context, {
  required String noteText,
  required String quote,
}) async {
  final compact = MediaQuery.sizeOf(context).width < 600;
  if (compact) {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.panel,
      builder: (context) =>
          _NxHighlightNoteViewer(noteText: noteText, quote: quote),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.line),
      ),
      child: _NxHighlightNoteViewer(noteText: noteText, quote: quote),
    ),
  );
}

class _NxHighlightNoteViewer extends StatelessWidget {
  const _NxHighlightNoteViewer({required this.noteText, required this.quote});

  final String noteText;
  final String quote;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return ConstrainedBox(
      key: const ValueKey<String>('highlight-note-reader'),
      constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 18,
                  color: AppColors.faint,
                ),
                const SizedBox(width: 9),
                Text(
                  'Highlight note',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (quote.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sidebar,
                  border: Border(
                    left: BorderSide(color: AppColors.faint, width: 3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  quote,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SelectableText(
              noteText.trim().isEmpty ? 'No note text.' : noteText,
              key: const ValueKey<String>('highlight-note-reader-text'),
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _suppressFloatingToolbar(EditorState editorState) {
  final currentSelection = editorState.selection?.normalized;
  if (currentSelection == null || currentSelection.isCollapsed) {
    return;
  }
  unawaited(
    editorState.updateSelectionWithReason(
      currentSelection,
      reason: SelectionUpdateReason.uiEvent,
      extraInfo: {selectionExtraInfoDisableToolbar: true},
    ),
  );
}

String? nxHighlightNoteText(EditorState editorState, String noteId) {
  final note = _highlightNotes(editorState.document.root.attributes)[noteId];
  final text = note?[nxHighlightNoteTextKey];
  return text is String ? text : null;
}

String? nxHighlightNoteIdInSelection(
  EditorState editorState,
  Selection selection,
) {
  final ids = <String>{};
  _visitTextInSelection(editorState, selection.normalized, (
    node,
    start,
    length,
    attributes,
  ) {
    final noteId = attributes?[nxHighlightNoteIdAttribute];
    if (noteId is String && noteId.trim().isNotEmpty) {
      ids.add(noteId);
    }
  });
  return ids.isEmpty ? null : ids.first;
}

const String nxHighlightNoteTextKey = 'text';

Future<void> _saveHighlightNote({
  required EditorState editorState,
  required Selection selection,
  required String? noteId,
  required String text,
  required String quote,
}) async {
  final normalized = selection.normalized;
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return;
  }

  final id = noteId ?? _newNoteId();
  final now = DateTime.now().toUtc().toIso8601String();
  final notes = _highlightNotes(editorState.document.root.attributes);
  final existing = notes[id] ?? const <String, dynamic>{};
  notes[id] = <String, dynamic>{
    ...existing,
    nxHighlightNoteTextKey: trimmed,
    'quote': quote,
    'created_at': existing['created_at'] ?? now,
    'updated_at': now,
  };

  final transaction = editorState.transaction;
  if (noteId == null) {
    final attributes = <String, dynamic>{nxHighlightNoteIdAttribute: id};
    if (!_selectionFullyHighlighted(editorState, normalized)) {
      attributes[AppFlowyRichTextKeys.backgroundColor] =
          _defaultNoteHighlightColor;
    }
    _formatSelection(
      editorState: editorState,
      transaction: transaction,
      selection: normalized,
      attributes: attributes,
    );
  }
  transaction.updateNode(editorState.document.root, {
    nxHighlightNotesDocumentAttribute: notes,
  });
  transaction.afterSelection = transaction.beforeSelection;
  await editorState.apply(transaction, withUpdateSelection: true);
}

Future<void> _deleteHighlightNote(
  EditorState editorState,
  String noteId,
) async {
  final notes = _highlightNotes(editorState.document.root.attributes)
    ..remove(noteId);
  final transaction = editorState.transaction;
  _removeNoteIdFromNode(
    node: editorState.document.root,
    noteId: noteId,
    transaction: transaction,
  );
  transaction.updateNode(editorState.document.root, {
    nxHighlightNotesDocumentAttribute: notes.isEmpty ? null : notes,
  });
  transaction.afterSelection = transaction.beforeSelection;
  await editorState.apply(transaction, withUpdateSelection: true);
}

bool _selectionFullyHighlighted(EditorState editorState, Selection selection) {
  var hasText = false;
  var fullyHighlighted = true;
  _visitTextInSelection(editorState, selection, (node, start, length, attrs) {
    hasText = true;
    if (attrs?[AppFlowyRichTextKeys.backgroundColor] == null) {
      fullyHighlighted = false;
    }
  });
  return hasText && fullyHighlighted;
}

void _formatSelection({
  required EditorState editorState,
  required Transaction transaction,
  required Selection selection,
  required Attributes attributes,
}) {
  final nodes = editorState.getNodesInSelection(selection);
  for (final node in nodes) {
    final delta = node.delta;
    if (delta == null) {
      continue;
    }
    final startIndex = node == nodes.first ? selection.startIndex : 0;
    final endIndex = node == nodes.last ? selection.endIndex : delta.length;
    if (endIndex <= startIndex) {
      continue;
    }
    transaction.formatText(node, startIndex, endIndex - startIndex, attributes);
  }
}

void _removeNoteIdFromNode({
  required Node node,
  required String noteId,
  required Transaction transaction,
}) {
  final delta = node.delta;
  if (delta != null) {
    var offset = 0;
    for (final op in delta.whereType<TextInsert>()) {
      if (op.attributes?[nxHighlightNoteIdAttribute] == noteId) {
        transaction.formatText(node, offset, op.length, {
          nxHighlightNoteIdAttribute: null,
        });
      }
      offset += op.length;
    }
  }
  for (final child in node.children) {
    _removeNoteIdFromNode(
      node: child,
      noteId: noteId,
      transaction: transaction,
    );
  }
}

void _visitTextInSelection(
  EditorState editorState,
  Selection selection,
  void Function(Node node, int start, int length, Attributes? attributes) visit,
) {
  final nodes = editorState.getNodesInSelection(selection);
  for (final node in nodes) {
    final delta = node.delta;
    if (delta == null) {
      continue;
    }
    final startIndex = node == nodes.first ? selection.startIndex : 0;
    final endIndex = node == nodes.last ? selection.endIndex : delta.length;
    var offset = 0;
    for (final op in delta.whereType<TextInsert>()) {
      final opEnd = offset + op.length;
      if (opEnd > startIndex && offset < endIndex) {
        final start = math.max(offset, startIndex);
        final end = math.min(opEnd, endIndex);
        visit(node, start, end - start, op.attributes);
      }
      offset = opEnd;
    }
  }
}

Map<String, Map<String, dynamic>> _highlightNotes(Attributes attributes) {
  final raw = attributes[nxHighlightNotesDocumentAttribute];
  if (raw is! Map) {
    return <String, Map<String, dynamic>>{};
  }
  return <String, Map<String, dynamic>>{
    for (final entry in raw.entries)
      if (entry.value is Map)
        entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
  };
}

String _newNoteId() {
  return 'note_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}
