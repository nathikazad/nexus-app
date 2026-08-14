part of 'nx_appflowy_blocks.dart';

Node nxExcalidrawNode() {
  return Node(
    type: nxExcalidrawBlockType,
    attributes: <String, Object?>{
      'title': 'Excalidraw',
      'scene': _emptyExcalidrawScene(),
      'preview_height': _defaultExcalidrawPreviewHeight,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    },
  );
}

class NxExcalidrawBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NxExcalidrawBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
      editorState: Provider.of<EditorState>(
        blockComponentContext.buildContext,
        listen: false,
      ),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.children.isEmpty;
}

class NxExcalidrawBlockComponentWidget extends BlockComponentStatefulWidget {
  const NxExcalidrawBlockComponentWidget({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    required this.editorState,
  });

  final EditorState editorState;

  @override
  State<NxExcalidrawBlockComponentWidget> createState() =>
      _NxExcalidrawBlockComponentWidgetState();
}

class _NxExcalidrawBlockComponentWidgetState
    extends State<NxExcalidrawBlockComponentWidget>
    with SelectableMixin {
  final _blockKey = GlobalKey(debugLabel: nxExcalidrawBlockType);
  double? _dragPreviewHeight;

  @override
  Widget build(BuildContext context) {
    final scene = _excalidrawSceneFromNode(widget.node);
    final previewHeight =
        _dragPreviewHeight ?? _excalidrawPreviewHeightFromNode(widget.node);
    Widget child = Padding(
      key: _blockKey,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _openEditor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SizedBox(
            height: previewHeight,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _ExcalidrawPreview(scene: scene),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: _ExcalidrawResizeHandle(
                    onVerticalDragUpdate: _resizePreview,
                    onVerticalDragEnd: (_) => _commitPreviewHeight(),
                    onVerticalDragCancel: _commitPreviewHeight,
                    onDoubleTap: _resetPreviewHeight,
                  ),
                ),
              ],
            ),
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
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }
    return child;
  }

  Future<void> _openEditor() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog.fullscreen(
          child: _ExcalidrawDialog(
            initialScene: _excalidrawSceneFromNode(widget.node),
            onSave: _saveScene,
          ),
        );
      },
    );
  }

  void _saveScene(Map<String, dynamic> scene) {
    final now = DateTime.now().toUtc().toIso8601String();
    final transaction = widget.editorState.transaction
      ..updateNode(widget.node, <String, Object?>{
        'scene': <String, dynamic>{...scene, 'updated_at': now},
        'updated_at': now,
      });
    widget.editorState.apply(transaction);
    if (mounted) {
      setState(() {});
    }
  }

  void _resizePreview(DragUpdateDetails details) {
    setState(() {
      _dragPreviewHeight = _clampExcalidrawPreviewHeight(
        (_dragPreviewHeight ?? _excalidrawPreviewHeightFromNode(widget.node)) +
            details.delta.dy,
      );
    });
  }

  void _commitPreviewHeight() {
    final height = _dragPreviewHeight;
    if (height == null) {
      return;
    }
    _savePreviewHeight(height);
    setState(() => _dragPreviewHeight = null);
  }

  void _resetPreviewHeight() {
    _savePreviewHeight(_defaultExcalidrawPreviewHeight);
    setState(() => _dragPreviewHeight = null);
  }

  void _savePreviewHeight(double height) {
    final now = DateTime.now().toUtc().toIso8601String();
    final transaction = widget.editorState.transaction
      ..updateNode(widget.node, <String, Object?>{
        'preview_height': _clampExcalidrawPreviewHeight(height),
        'updated_at': now,
      });
    widget.editorState.apply(transaction);
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

class _ExcalidrawResizeHandle extends StatelessWidget {
  const _ExcalidrawResizeHandle({
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
    required this.onDoubleTap,
  });

  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;
  final GestureTapCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        onVerticalDragCancel: onVerticalDragCancel,
        onDoubleTap: onDoubleTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Align(
            alignment: Alignment.bottomRight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SizedBox(
                width: 18,
                height: 18,
                child: Icon(
                  Icons.drag_handle,
                  size: 14,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
