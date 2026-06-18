import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/domain/links/linked_model.dart';

typedef NxSearchLinkableModels =
    Future<List<LinkedModel>> Function({
      required LinkableModelType modelType,
      required String query,
    });

typedef NxCreateLinkedDocument = Future<LinkedModel> Function(String title);

typedef NxLinkableModelSelected =
    Future<void> Function(LinkableModelType modelType, LinkedModel model);

String nxKgqlHrefForModel(LinkableModelType modelType, LinkedModel model) {
  return 'kgql://${modelType.kgqlName}/${model.id}';
}

bool nxIsDocumentHref(String? href) => nxDocumentIdFromHref(href) != null;

int? nxDocumentIdFromHref(String? href) {
  if (href == null || href.trim().isEmpty) return null;
  final uri = Uri.tryParse(href.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'kgql') return null;
  final modelType = uri.host.toLowerCase();
  if (modelType != LinkableModelType.document.kgqlName.toLowerCase() &&
      modelType != 'essay') {
    return null;
  }
  final idText = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  return int.tryParse(idText ?? '');
}

ToolbarItem buildNxDocumentLinkToolbarItem({
  required NxSearchLinkableModels searchLinkableModels,
  required NxCreateLinkedDocument createDocument,
  required NxLinkableModelSelected onLinkableModelSelected,
}) {
  return ToolbarItem(
    id: 'nx.documentLink',
    group: 4,
    isActive: onlyShowInSingleSelectionAndTextType,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      final selection = editorState.selection?.normalized;
      final disabled = selection == null || selection.isCollapsed;
      final isDocumentLink =
          selection != null && _selectionIsDocumentLink(editorState, selection);
      final effectiveIconColor = disabled
          ? (iconColor ?? Colors.white).withValues(alpha: 0.35)
          : isDocumentLink
          ? highlightColor
          : iconColor;
      final child = SizedBox(
        width: 30,
        height: 30,
        child: IconButton(
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          padding: EdgeInsets.zero,
          tooltip: 'Document',
          icon: Icon(
            Icons.description_outlined,
            color: effectiveIconColor,
            size: 18,
          ),
          onPressed: disabled
              ? null
              : () {
                  showNxDocumentLinkPicker(
                    context: context,
                    editorState: editorState,
                    selection: selection,
                    initialQuery: editorState
                        .getTextInSelection(selection)
                        .join(' ')
                        .trim(),
                    searchLinkableModels: searchLinkableModels,
                    createDocument: createDocument,
                    onSelected: (model) async {
                      await nxApplyDocumentLinkToSelection(
                        editorState: editorState,
                        selection: selection,
                        model: model,
                        onLinkableModelSelected: onLinkableModelSelected,
                      );
                    },
                  );
                },
        ),
      );

      if (tooltipBuilder == null) {
        return child;
      }
      return tooltipBuilder(context, 'nx.documentLink', 'Document', child);
    },
  );
}

Future<void> nxApplyDocumentLinkToSelection({
  required EditorState editorState,
  required Selection selection,
  required LinkedModel model,
  required NxLinkableModelSelected onLinkableModelSelected,
}) async {
  await editorState.formatDelta(selection.normalized, {
    BuiltInAttributeKey.href: nxKgqlHrefForModel(
      LinkableModelType.document,
      model,
    ),
  });
  await onLinkableModelSelected(LinkableModelType.document, model);
}

void showNxDocumentLinkPicker({
  required BuildContext context,
  required EditorState editorState,
  required Selection selection,
  required String initialQuery,
  required NxSearchLinkableModels searchLinkableModels,
  required NxCreateLinkedDocument createDocument,
  required Future<void> Function(LinkedModel model) onSelected,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final anchor = _selectionAnchor(context, editorState);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      const width = 360.0;
      const maxHeight = 360.0;
      const margin = 8.0;
      final left = anchor.dx.clamp(margin, size.width - width - margin);
      final top = anchor.dy.clamp(margin, size.height - maxHeight - margin);
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (entry.mounted) entry.remove();
              },
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: NxDocumentLinkPicker(
              initialQuery: initialQuery,
              searchLinkableModels: searchLinkableModels,
              createDocument: createDocument,
              onSelected: (model) async {
                await onSelected(model);
                if (entry.mounted) entry.remove();
              },
              onDismiss: () {
                if (entry.mounted) entry.remove();
              },
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
}

Offset _selectionAnchor(BuildContext context, EditorState editorState) {
  final buttonBox = context.findRenderObject() as RenderBox?;
  final buttonAnchor =
      buttonBox?.localToGlobal(Offset(0, buttonBox.size.height + 8)) ??
      Offset.zero;
  final rects = editorState.selectionRects();
  final rect = rects.isEmpty ? null : rects.first;
  if (rect == null) {
    return buttonAnchor;
  }
  return Offset(rect.left, rect.bottom + 8);
}

bool _selectionIsDocumentLink(EditorState editorState, Selection selection) {
  final nodes = editorState.getNodesInSelection(selection);
  if (nodes.isEmpty) return false;
  return nodes.allSatisfyInSelection(selection, (delta) {
    return delta.everyAttributes((attributes) {
      return nxIsDocumentHref(attributes[BuiltInAttributeKey.href] as String?);
    });
  });
}

class NxDocumentLinkPicker extends StatefulWidget {
  const NxDocumentLinkPicker({
    required this.initialQuery,
    required this.searchLinkableModels,
    required this.createDocument,
    required this.onSelected,
    required this.onDismiss,
    super.key,
  });

  final String initialQuery;
  final NxSearchLinkableModels searchLinkableModels;
  final NxCreateLinkedDocument createDocument;
  final Future<void> Function(LinkedModel model) onSelected;
  final VoidCallback onDismiss;

  @override
  State<NxDocumentLinkPicker> createState() => _NxDocumentLinkPickerState();
}

class _NxDocumentLinkPickerState extends State<NxDocumentLinkPicker> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode(debugLabel: 'nx_document_link_picker');
  Timer? _debounce;
  var _requestId = 0;
  var _loading = false;
  var _busy = false;
  List<LinkedModel> _results = const <LinkedModel>[];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _controller.addListener(_scheduleSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller
      ..removeListener(_scheduleSearch)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _search);
  }

  Future<void> _search() async {
    final requestId = ++_requestId;
    final query = _controller.text.trim();
    setState(() => _loading = true);
    try {
      final results = await widget.searchLinkableModels(
        modelType: LinkableModelType.document,
        query: query,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _results = results;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _results = const <LinkedModel>[];
      });
    }
  }

  Future<void> _select(LinkedModel model) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSelected(model);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final model = await widget.createDocument(_createTitle);
      await widget.onSelected(model);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _createTitle {
    final query = _controller.text.trim();
    return query.isEmpty ? 'Untitled document' : query;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1f000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_busy,
                  cursorColor: AppColors.text,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    hintStyle: const TextStyle(
                      color: AppColors.faint,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.faint,
                      size: 17,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Close',
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close, size: 16),
                      color: AppColors.faint,
                    ),
                    filled: true,
                    fillColor: AppColors.sidebar,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: _inputBorder(AppColors.line),
                    enabledBorder: _inputBorder(AppColors.line),
                    focusedBorder: _inputBorder(const Color(0xffd4d4d8)),
                  ),
                  onSubmitted: (_) {
                    unawaited(_create());
                  },
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: <Widget>[
                    _DocumentPickerTile(
                      icon: Icons.add,
                      title: 'Create "$_createTitle"',
                      subtitle: 'New document',
                      enabled: !_busy,
                      onTap: _create,
                    ),
                    if (_loading)
                      const _DocumentPickerMessage(text: 'Loading documents...')
                    else if (_results.isEmpty)
                      const _DocumentPickerMessage(
                        text: 'No existing documents',
                      )
                    else
                      for (final model in _results.take(12))
                        _DocumentPickerTile(
                          icon: Icons.article_outlined,
                          title: model.name,
                          subtitle: 'Existing document',
                          enabled: !_busy,
                          onTap: () => unawaited(_select(model)),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );
  }
}

class _DocumentPickerTile extends StatelessWidget {
  const _DocumentPickerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.sidebar,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: AppColors.muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentPickerMessage extends StatelessWidget {
  const _DocumentPickerMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}
