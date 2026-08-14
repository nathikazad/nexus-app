part of 'document_editor_view.dart';

class NxSelectionFormattingToolbar extends StatefulWidget {
  const NxSelectionFormattingToolbar({
    required this.editorState,
    required this.editorScrollController,
    required this.child,
    super.key,
  });

  final EditorState editorState;
  final EditorScrollController editorScrollController;
  final Widget child;

  @override
  State<NxSelectionFormattingToolbar> createState() =>
      _NxSelectionFormattingToolbarState();
}

class _NxSelectionFormattingToolbarState
    extends State<NxSelectionFormattingToolbar> {
  static const _toolbarHeight = 34.0;
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
  void didUpdateWidget(covariant NxSelectionFormattingToolbar oldWidget) {
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
    final left = rect.center.dx - 95;
    final top = rect.top - _toolbarHeight - 8;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left < 8 ? 8 : left,
        top: top < 8 ? rect.bottom + 8 : top,
        child: _NxFormattingToolbarSurface(
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

class _NxFormattingToolbarSurface extends StatelessWidget {
  const _NxFormattingToolbarSurface({
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
              _formatButton('B', 'bold', FontWeight.w700),
              _formatButton('I', 'italic', FontWeight.w500),
              _formatButton('U', 'underline', FontWeight.w500),
              _formatButton('S', 'strikethrough', FontWeight.w500),
              _formatButton('</>', 'code', FontWeight.w600, wide: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatButton(
    String label,
    String attribute,
    FontWeight fontWeight, {
    bool wide = false,
  }) {
    return Tooltip(
      message: attribute,
      preferBelow: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _toggle(attribute),
        child: SizedBox(
          width: wide ? 38 : 28,
          height: 28,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.onFloating,
                fontSize: wide ? 11 : 13,
                fontWeight: fontWeight,
                fontStyle: attribute == 'italic' ? FontStyle.italic : null,
                decoration: attribute == 'underline'
                    ? TextDecoration.underline
                    : attribute == 'strikethrough'
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: AppColors.onFloating,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggle(String attribute) {
    editorState.toggleAttribute(attribute, selection: selection);
  }
}

EditorStyle _editorStyle(
  _DocumentEditorMode mode, {
  required double textScaleFactor,
}) {
  final readMode = mode == _DocumentEditorMode.read;
  final bodyStyle = readMode
      ? TextStyle(color: _readModeTextColor(), fontSize: 18, height: 1.6)
      : TextStyle(color: AppColors.editorText, fontSize: 16, height: 1.62);
  final lineHeight = readMode ? 1.6 : 1.62;
  return EditorStyle.desktop(
    textScaleFactor: textScaleFactor,
    cursorColor: AppColors.text,
    selectionColor: const Color(0x333B82F6),
    padding: EdgeInsets.zero,
    textSpanDecorator: nxHighlightNoteTextSpanDecorator,
    textSpanOverlayBuilder: nxHighlightNoteOverlayBuilder,
    textStyleConfiguration: TextStyleConfiguration(
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
    ),
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
