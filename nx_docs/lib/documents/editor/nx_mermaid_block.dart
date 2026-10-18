part of 'nx_appflowy_blocks.dart';

Node nxMermaidNode({String source = defaultMermaidSource}) => Node(
  type: nxMermaidBlockType,
  attributes: {'source': source, 'preview_height': 420.0},
);

class NxMermaidBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentValidate get validate =>
      (node) => node.children.isEmpty;
  @override
  BlockComponentWidget build(BlockComponentContext context) => _MermaidBlock(
    key: context.node.key,
    node: context.node,
    configuration: configuration,
    showActions: showActions(context.node),
    actionBuilder: (c, s) => actionBuilder(context, s),
    editorState: Provider.of<EditorState>(context.buildContext, listen: false),
  );
}

class _MermaidBlock extends BlockComponentStatefulWidget {
  const _MermaidBlock({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
    required this.editorState,
  });
  final EditorState editorState;
  @override
  State<_MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<_MermaidBlock> with SelectableMixin {
  final _blockKey = GlobalKey();
  bool _opening = false;
  String get _source => _stringAttribute(widget.node, 'source', '');

  Future<void> _openViewer() async {
    if (_opening) return;
    _opening = true;
    try {
      await showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (_) =>
            Dialog.fullscreen(child: NxMermaidViewer(source: _source)),
      );
    } finally {
      _opening = false;
    }
  }

  Future<void> _openEditor() async {
    if (_opening) return;
    _opening = true;
    final originalSource = _source;
    try {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog.fullscreen(
          child: NxMermaidEditor(
            source: originalSource,
            readOnly: !widget.editorState.editable,
          ),
        ),
      );
      if (!mounted || result == null || !widget.editorState.editable) return;
      // Do not overwrite a remotely replaced/deleted block or a newer source.
      if (widget.editorState.document.nodeAtPath(widget.node.path) !=
              widget.node ||
          _source != originalSource) {
        return;
      }
      if (result != originalSource) {
        await widget.editorState.apply(
          widget.editorState.transaction
            ..updateNode(widget.node, {'source': result}),
        );
        if (mounted) setState(() {});
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = _doubleValue(
      widget.node.attributes['preview_height'],
      fallback: 420,
    ).clamp(160.0, 800.0);
    Widget child = Padding(
      key: _blockKey,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openViewer,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Mermaid', overflow: TextOverflow.ellipsis),
                    ),
                    TextButton.icon(
                      onPressed: _openViewer,
                      icon: const Icon(Icons.open_in_full, size: 18),
                      label: const Text('View'),
                    ),
                    TextButton.icon(
                      onPressed: _openEditor,
                      icon: Icon(
                        widget.editorState.editable
                            ? Icons.edit_outlined
                            : Icons.code,
                        size: 18,
                      ),
                      label: Text(
                        widget.editorState.editable ? 'Edit' : 'Source',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: height,
                width: double.infinity,
                child: IgnorePointer(child: NxMermaidPreview(source: _source)),
              ),
            ],
          ),
        ),
      ),
    );
    child = _wrapBlockSelection(
      node: widget.node,
      delegate: this,
      editorState: widget.editorState,
      child: child,
    );
    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: widget.node,
        actionBuilder: widget.actionBuilder!,
        child: child,
      );
    }
    return child;
  }

  RenderBox? get _renderBox =>
      _blockKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    return getRectsInSelection(Selection.invalid()).firstOrNull ?? Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    return getRectsInSelection(
      Selection.collapsed(position),
      shiftWithBaseOffset: shiftWithBaseOffset,
    ).firstOrNull;
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final renderBox = _renderBox;
    if (renderBox == null) {
      return <Rect>[];
    }
    return <Rect>[Offset.zero & renderBox.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    return _renderBox?.localToGlobal(offset) ?? Offset.zero;
  }
}
