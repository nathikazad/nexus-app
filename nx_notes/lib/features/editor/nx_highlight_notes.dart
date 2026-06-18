import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/features/editor/nx_document_link.dart';
import 'package:provider/provider.dart';

const String nxHighlightNoteIdAttribute = 'nx_note_id';
const String nxHighlightNotesDocumentAttribute = 'nx_highlight_notes';
const String _defaultNoteHighlightColor = '0x4def4444';

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
        editorState.updateSelectionWithReason(
          selection,
          reason: SelectionUpdateReason.uiEvent,
        );
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
  final normalized = selection.normalized;
  final effectiveNoteId =
      noteId ?? nxHighlightNoteIdInSelection(editorState, normalized);
  final initialText = effectiveNoteId == null
      ? ''
      : nxHighlightNoteText(editorState, effectiveNoteId) ?? '';
  final quote = editorState.getTextInSelection(normalized).join('\n').trim();
  final result = await showDialog<_NxHighlightNoteDialogResult>(
    context: context,
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

enum _NxHighlightNoteDialogAction { save, delete }

class _NxHighlightNoteDialogResult {
  const _NxHighlightNoteDialogResult.save(this.text)
    : action = _NxHighlightNoteDialogAction.save;

  const _NxHighlightNoteDialogResult.delete()
    : action = _NxHighlightNoteDialogAction.delete,
      text = '';

  final _NxHighlightNoteDialogAction action;
  final String text;
}

class _NxHighlightNoteDialog extends StatefulWidget {
  const _NxHighlightNoteDialog({
    required this.initialText,
    required this.quote,
    required this.canDelete,
  });

  final String initialText;
  final String quote;
  final bool canDelete;

  @override
  State<_NxHighlightNoteDialog> createState() => _NxHighlightNoteDialogState();
}

class _NxHighlightNoteDialogState extends State<_NxHighlightNoteDialog> {
  late final TextEditingController _controller;
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _canSave = _controller.text.trim().isNotEmpty;
    _controller.addListener(_updateCanSave);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateCanSave)
      ..dispose();
    super.dispose();
  }

  void _updateCanSave() {
    final canSave = _controller.text.trim().isNotEmpty;
    if (canSave != _canSave) {
      setState(() => _canSave = canSave);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 17,
                    color: AppColors.faint,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Highlight note',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.quote.isNotEmpty) ...[
                const Text(
                  'Selection',
                  style: TextStyle(
                    color: AppColors.faint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sidebar,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.quote,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Text(
                'Note',
                style: TextStyle(
                  color: AppColors.faint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 5,
                maxLines: 9,
                cursorColor: AppColors.text,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note...',
                  hintStyle: const TextStyle(
                    color: AppColors.faint,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.sidebar,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border: _noteInputBorder(AppColors.line),
                  enabledBorder: _noteInputBorder(AppColors.line),
                  focusedBorder: _noteInputBorder(const Color(0xffd4d4d8)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  if (widget.canDelete)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(const _NxHighlightNoteDialogResult.delete());
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Delete note'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _canSave
                        ? () {
                            Navigator.of(context).pop(
                              _NxHighlightNoteDialogResult.save(
                                _controller.text,
                              ),
                            );
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.text,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.hover,
                      disabledForegroundColor: AppColors.faint,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _noteInputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );
  }
}

class _NxInlineHoverTarget extends StatelessWidget {
  const _NxInlineHoverTarget({
    required this.editorState,
    required this.selection,
    required this.noteId,
    required this.noteText,
    required this.href,
  });

  final EditorState editorState;
  final Selection selection;
  final String? noteId;
  final String? noteText;
  final String? href;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) {
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
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final link = href;
          if (link != null) {
            unawaited(editorLaunchUrl(link));
            return;
          }
          final id = noteId;
          if (id == null) {
            return;
          }
          editorState.updateSelectionWithReason(
            selection,
            reason: SelectionUpdateReason.uiEvent,
          );
          unawaited(
            showNxHighlightNoteDialog(
              context,
              editorState,
              selection,
              noteId: id,
            ),
          );
        },
      ),
    );
  }
}

class _NxInlineHoverOverlay {
  static OverlayEntry? _entry;
  static Timer? _hideTimer;

  static void show({
    required BuildContext context,
    required EditorState editorState,
    required Offset position,
    required String? noteText,
    required String? href,
    required Selection selection,
  }) {
    final hasNote = noteText != null && noteText.trim().isNotEmpty;
    if (!hasNote && href == null) {
      return;
    }
    hide();
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        const margin = 8.0;
        const gap = 12.0;
        final editorWidth = editorState.renderBox?.size.width ?? size.width;
        final maxWidth = math.min(
          math.max(editorWidth * 0.7, size.width * 0.52),
          size.width - margin * 2,
        );
        final fixedWidth =
            _expandedHoverNoteWidth(noteText ?? href ?? '', maxWidth) ??
            (href == null ? null : math.min(360.0, maxWidth));
        final horizontalFootprint = fixedWidth ?? maxWidth;
        final left = (position.dx + gap).clamp(
          margin,
          size.width - horizontalFootprint - margin,
        );
        final belowSpace = size.height - position.dy - gap - margin;
        final aboveSpace = position.dy - gap - margin;
        final showAbove = belowSpace < 180 && aboveSpace > belowSpace;
        final availableHeight = showAbove ? aboveSpace : belowSpace;
        final maxHeight = math.max(80.0, math.min(420.0, availableHeight));
        final top = showAbove ? null : position.dy + gap;
        final bottom = showAbove ? size.height - position.dy + gap : null;
        return Positioned(
          left: left,
          top: top,
          bottom: bottom,
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              onEnter: (_) => _cancelHide(),
              onExit: (_) => scheduleHide(),
              child: SizedBox(
                width: fixedWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (hasNote)
                              Text(
                                noteText,
                                textWidthBasis: fixedWidth == null
                                    ? TextWidthBasis.longestLine
                                    : TextWidthBasis.parent,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            if (hasNote && href != null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                  height: 1,
                                  color: Color(0x33ffffff),
                                ),
                              ),
                            if (href != null)
                              _NxInlineLinkActions(
                                href: href,
                                onOpen: () {
                                  hide();
                                  unawaited(editorLaunchUrl(href));
                                },
                                onCopy: () {
                                  unawaited(
                                    Clipboard.setData(
                                      ClipboardData(text: href),
                                    ),
                                  );
                                  hide();
                                },
                                onRemove: () {
                                  unawaited(
                                    editorState.formatDelta(selection, {
                                      BuiltInAttributeKey.href: null,
                                    }),
                                  );
                                  hide();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  static void scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 160), hide);
  }

  static void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _entry?.remove();
    _entry = null;
  }

  static void _cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }
}

class _NxInlineLinkActions extends StatelessWidget {
  const _NxInlineLinkActions({
    required this.href,
    required this.onOpen,
    required this.onCopy,
    required this.onRemove,
  });

  final String href;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final documentId = nxDocumentIdFromHref(href);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          documentId == null ? href : 'Document $documentId',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            _NxInlineHoverButton(
              icon: Icons.open_in_new,
              label: 'Open',
              onPressed: onOpen,
            ),
            _NxInlineHoverButton(
              icon: Icons.copy,
              label: 'Copy',
              onPressed: onCopy,
            ),
            _NxInlineHoverButton(
              icon: Icons.link_off,
              label: 'Remove',
              onPressed: onRemove,
            ),
          ],
        ),
      ],
    );
  }
}

class _NxInlineHoverButton extends StatelessWidget {
  const _NxInlineHoverButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0x1fffffff),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 13),
      label: Text(label),
    );
  }
}

double? _expandedHoverNoteWidth(String text, double maxWidth) {
  final trimmed = text.trim();
  final lines = trimmed.split('\n');
  final longestLine = lines.fold<int>(
    0,
    (longest, line) => math.max(longest, line.trimRight().length),
  );
  final shouldExpand =
      trimmed.length >= 120 || lines.length >= 3 || longestLine >= 80;
  return shouldExpand ? maxWidth : null;
}
