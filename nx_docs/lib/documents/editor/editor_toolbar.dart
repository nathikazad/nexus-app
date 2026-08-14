part of 'document_editor_view.dart';

bool canPersistDocumentTransaction(
  DocumentInteractionMode interactionMode,
  Transaction transaction,
) {
  if (interactionMode == DocumentInteractionMode.edit) return true;
  if (interactionMode != DocumentInteractionMode.highlightOnly) return false;
  return transaction.operations.every(_operationOnlyChangesHighlight);
}

bool _operationOnlyChangesHighlight(Operation operation) {
  if (operation is! UpdateOperation ||
      operation.attributes.length != 1 ||
      !operation.attributes.containsKey(blockComponentDelta)) {
    return false;
  }
  final beforeJson = operation.oldAttributes[blockComponentDelta];
  final afterJson = operation.attributes[blockComponentDelta];
  if (beforeJson is! List || afterJson is! List) return false;
  final before = Delta.fromJson(beforeJson);
  final after = Delta.fromJson(afterJson);
  final beforeWithoutHighlight = _canonicalTextRuns(
    before,
    removeHighlight: true,
  );
  final afterWithoutHighlight = _canonicalTextRuns(
    after,
    removeHighlight: true,
  );
  if (beforeWithoutHighlight == null ||
      afterWithoutHighlight == null ||
      !_sameTextRuns(beforeWithoutHighlight, afterWithoutHighlight)) {
    return false;
  }
  final beforeWithHighlight = _canonicalTextRuns(before);
  final afterWithHighlight = _canonicalTextRuns(after);
  return beforeWithHighlight != null &&
      afterWithHighlight != null &&
      !_sameTextRuns(beforeWithHighlight, afterWithHighlight);
}

List<({String text, Attributes attributes})>? _canonicalTextRuns(
  Delta delta, {
  bool removeHighlight = false,
}) {
  final runs = <({String text, Attributes attributes})>[];
  for (final operation in delta) {
    if (operation is! TextInsert) return null;
    final attributes = <String, dynamic>{...?operation.attributes};
    if (removeHighlight) {
      attributes.remove(AppFlowyRichTextKeys.backgroundColor);
    }
    if (runs.isNotEmpty && mapEquals(runs.last.attributes, attributes)) {
      final previous = runs.removeLast();
      runs.add((text: previous.text + operation.text, attributes: attributes));
    } else {
      runs.add((text: operation.text, attributes: attributes));
    }
  }
  return runs;
}

bool _sameTextRuns(
  List<({String text, Attributes attributes})> left,
  List<({String text, Attributes attributes})> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].text != right[index].text ||
        !mapEquals(left[index].attributes, right[index].attributes)) {
      return false;
    }
  }
  return true;
}

class NxReaderHighlightToolbar extends StatefulWidget {
  const NxReaderHighlightToolbar({
    required this.editorState,
    required this.editorScrollController,
    required this.child,
    super.key,
  });

  final EditorState editorState;
  final EditorScrollController editorScrollController;
  final Widget child;

  @override
  State<NxReaderHighlightToolbar> createState() =>
      _NxReaderHighlightToolbarState();
}

class _NxReaderHighlightToolbarState extends State<NxReaderHighlightToolbar> {
  static const _toolbarHeight = 42.0;
  static const _toolbarWidth = 152.0;
  OverlayEntry? _overlayEntry;
  Selection? _toolbarSelection;
  Timer? _showTimer;

  EditorState get _editorState => widget.editorState;

  @override
  void initState() {
    super.initState();
    _editorState.selectionNotifier.addListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.addListener(_hideToolbar);
  }

  @override
  void didUpdateWidget(covariant NxReaderHighlightToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      oldWidget.editorState.selectionNotifier.removeListener(
        _onSelectionChanged,
      );
      widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    }
    if (oldWidget.editorScrollController != widget.editorScrollController) {
      oldWidget.editorScrollController.offsetNotifier.removeListener(
        _hideToolbar,
      );
      widget.editorScrollController.offsetNotifier.addListener(_hideToolbar);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideToolbar();
    _editorState.selectionNotifier.removeListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.removeListener(_hideToolbar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onSelectionChanged() {
    final selection = _editorState.selection;
    if (selection == null ||
        selection.isCollapsed ||
        _editorState.selectionType == SelectionType.block ||
        !_selectionContainsText(selection)) {
      _hideToolbar();
      return;
    }

    _toolbarSelection = selection.normalized;
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 80), _showToolbar);
  }

  bool _selectionContainsText(Selection selection) {
    final nodes = _editorState.getNodesInSelection(selection);
    return nodes.any((node) {
      final delta = node.delta;
      return delta != null && delta.isNotEmpty;
    });
  }

  void _showToolbar() {
    final selection = _toolbarSelection;
    if (selection == null || !mounted) {
      return;
    }
    final rects = _editorState.selectionRects();
    if (rects.isEmpty) {
      return;
    }

    final rect = rects.reduce((a, b) => a.top <= b.top ? a : b);
    final overlay = Overlay.of(context, rootOverlay: true);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final left = (rect.center.dx - _toolbarWidth / 2).clamp(
      8.0,
      screenWidth - _toolbarWidth - 8,
    );
    final top = rect.top - _toolbarHeight - 8;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top < 8 ? rect.bottom + 8 : top,
        child: _NxReaderHighlightToolbarSurface(
          selection: selection,
          editorState: _editorState,
          onClose: _hideToolbar,
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _hideToolbar() {
    _showTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _NxReaderHighlightToolbarSurface extends StatelessWidget {
  const _NxReaderHighlightToolbarSurface({
    required this.selection,
    required this.editorState,
    required this.onClose,
  });

  final Selection selection;
  final EditorState editorState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.floating,
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _clearButton(),
              for (final option in nxReaderHighlightColorOptions())
                _highlightButton(option),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clearButton() {
    return Tooltip(
      message: 'Remove highlight',
      preferBelow: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apply(null),
        child: SizedBox(
          key: const ValueKey<String>('reader-highlight-clear'),
          width: 36,
          height: 36,
          child: Icon(
            Icons.format_color_reset_rounded,
            size: 19,
            color: AppColors.onFloating,
          ),
        ),
      ),
    );
  }

  Widget _highlightButton(ColorOption option) {
    return Tooltip(
      message: option.name,
      preferBelow: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apply(option.colorHex),
        child: SizedBox(
          key: ValueKey<String>('reader-highlight-${option.colorHex}'),
          width: 36,
          height: 36,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: option.colorHex.tryToColor(),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.onFloating, width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _apply(String? colorHex) {
    unawaited(
      applyNxHighlightColor(
        editorState: editorState,
        selection: selection,
        colorHex: colorHex,
      ),
    );
    onClose();
  }
}

EditorStyle _editorStyle(
  _DocumentEditorMode mode, {
  required double textScaleFactor,
  required bool useMobileSelectionHandles,
}) {
  final readMode = mode == _DocumentEditorMode.read;
  final bodyStyle = readMode
      ? TextStyle(color: _readModeTextColor(), fontSize: 18, height: 1.6)
      : TextStyle(color: AppColors.editorText, fontSize: 16, height: 1.62);
  final lineHeight = readMode ? 1.6 : 1.62;
  final textStyleConfiguration = TextStyleConfiguration(
    text: bodyStyle,
    bold: const TextStyle(fontWeight: FontWeight.w700),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    underline: const TextStyle(decoration: TextDecoration.underline),
    strikethrough: const TextStyle(decoration: TextDecoration.lineThrough),
    href: TextStyle(
      foreground: Paint()..color = AppColors.blue,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.blue,
    ),
    code: TextStyle(
      color: AppColors.text,
      backgroundColor: AppColors.subtle,
      fontFamily: 'monospace',
    ),
    lineHeight: lineHeight,
  );
  if (useMobileSelectionHandles) {
    return EditorStyle.mobile(
      textScaleFactor: textScaleFactor,
      cursorColor: AppColors.text,
      dragHandleColor: AppColors.blue,
      selectionColor: const Color(0x333B82F6),
      padding: EdgeInsets.zero,
      textSpanDecorator: nxHighlightNoteTextSpanDecorator,
      textSpanOverlayBuilder: nxHighlightNoteOverlayBuilder,
      textStyleConfiguration: textStyleConfiguration,
    );
  }
  return EditorStyle.desktop(
    textScaleFactor: textScaleFactor,
    cursorColor: AppColors.text,
    selectionColor: const Color(0x333B82F6),
    padding: EdgeInsets.zero,
    textSpanDecorator: nxHighlightNoteTextSpanDecorator,
    textSpanOverlayBuilder: nxHighlightNoteOverlayBuilder,
    textStyleConfiguration: textStyleConfiguration,
  );
}

Color _readModeBackgroundColor() {
  return AppColors.isDark ? const Color(0xff171512) : const Color(0xfff6f5f1);
}

Color _readModeTextColor() {
  return AppColors.isDark ? const Color(0xffe8e1d5) : const Color(0xff25231f);
}

class EditorContextBar extends StatelessWidget {
  const EditorContextBar({
    required this.resultContext,
    required this.activeDocumentId,
    required this.onBack,
    required this.onClear,
    super.key,
  });

  final DocumentResultContext resultContext;
  final int activeDocumentId;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final index = resultContext.resultIds.indexOf(activeDocumentId);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.muted,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('Back to ${resultContext.title}'),
          ),
          const Spacer(),
          Text(
            '${index + 1} of ${resultContext.resultIds.length}',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: Icon(Icons.close, size: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
