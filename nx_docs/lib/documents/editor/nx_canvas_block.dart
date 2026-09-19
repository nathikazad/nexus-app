part of 'nx_appflowy_blocks.dart';

class NxCanvasBlockComponentBuilder extends BlockComponentBuilder {
  NxCanvasBlockComponentBuilder({
    this.documentId,
    this.persist,
    this.isIdentityPersisted,
  });
  final String? documentId;
  final Future<void> Function()? persist;
  final bool Function(String id)? isIdentityPersisted;
  @override
  BlockComponentValidate get validate =>
      (node) => node.children.isEmpty;
  @override
  BlockComponentWidget build(BlockComponentContext context) => _CanvasBlock(
    key: context.node.key,
    node: context.node,
    configuration: configuration,
    showActions: showActions(context.node),
    actionBuilder: (c, s) => actionBuilder(context, s),
    editor: Provider.of<EditorState>(context.buildContext, listen: false),
    documentId: documentId,
    persist: persist,
    isIdentityPersisted: isIdentityPersisted,
  );
}

class _CanvasBlock extends BlockComponentStatefulWidget {
  const _CanvasBlock({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
    required this.editor,
    this.documentId,
    this.persist,
    this.isIdentityPersisted,
  });
  final EditorState editor;
  final String? documentId;
  final Future<void> Function()? persist;
  final bool Function(String id)? isIdentityPersisted;
  @override
  State<_CanvasBlock> createState() => _CanvasBlockState();
}

class _CanvasBlockState extends State<_CanvasBlock> with SelectableMixin {
  final _blockKey = GlobalKey();
  double? _height;
  bool _opening = false;
  String? _error;
  bool get _canEdit =>
      widget.editor.editable &&
      widget.persist != null &&
      widget.documentId != null;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  NxCanvasSession get _session => NxCanvasSession(
    editor: widget.editor,
    documentId: widget.documentId!,
    persist: widget.persist!,
    isIdentityPersisted: widget.isIdentityPersisted,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  Future<void> _recover() async {
    if (!mounted || !_canEdit || !_android || _opening) return;
    _opening = true;
    try {
      await _session.recover(widget.node);
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    if (!_canEdit || !_android) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: const Text('Canvas')),
            body: InteractiveViewer(
              minScale: .2,
              maxScale: 8,
              child: SizedBox.expand(child: _preview()),
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    final session = _session;
    try {
      await session.open(widget.node);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) session.reportReturnFrame();
        });
      }
    }
  }

  Widget _preview() {
    try {
      final drawing = canvasDrawing(widget.node);
      if (drawing.strokes.isEmpty) {
        return Center(
          child: Text(_canEdit && _android ? 'Tap to draw' : 'Empty canvas'),
        );
      }
      return CustomPaint(painter: _CanvasOverviewPainter(drawing));
    } catch (_) {
      return const Center(child: Text('Cannot display this canvas format'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height =
        _height ??
        (widget.node.attributes['preview_height'] as num?)?.toDouble() ??
        280;
    Widget child = Padding(
      key: _blockKey,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _open,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _preview(),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 6,
                    child: Text(
                      _opening ? 'Opening canvas…' : 'Canvas',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                  if (_canEdit)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: _ExcalidrawResizeHandle(
                        onVerticalDragUpdate: (d) => setState(
                          () => _height = ((_height ?? height) + d.delta.dy)
                              .clamp(140.0, 900.0),
                        ),
                        onVerticalDragEnd: (_) => _saveHeight(),
                        onVerticalDragCancel: _saveHeight,
                        onDoubleTap: () {
                          _height = 280;
                          _saveHeight();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
    child = _wrapBlockSelection(
      node: widget.node,
      delegate: this,
      editorState: widget.editor,
      child: child,
    );
    if (widget.showActions && widget.actionBuilder != null && _canEdit) {
      child = BlockComponentActionWrapper(
        node: widget.node,
        actionBuilder: widget.actionBuilder!,
        child: child,
      );
    }
    return child;
  }

  void _saveHeight() {
    if (_height == null || !_canEdit) return;
    unawaited(
      widget.editor.apply(
        widget.editor.transaction
          ..updateNode(widget.node, {'preview_height': _height}),
      ),
    );
    setState(() => _height = null);
  }

  RenderBox? get _box =>
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
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      getRectsInSelection(Selection.invalid()).firstOrNull ?? Rect.zero;
  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) => getBlockRect();
  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) => _box == null ? [] : [Offset.zero & _box!.size];
  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);
  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _box?.localToGlobal(offset) ?? Offset.zero;
}

class _CanvasOverviewPainter extends CustomPainter {
  _CanvasOverviewPainter(this.drawing);
  final Drawing drawing;
  @override
  void paint(Canvas canvas, Size size) {
    final points = drawing.strokes.expand((s) => s.points).toList();
    if (points.isEmpty) return;
    final minX = points.map((p) => p.x).reduce(math.min),
        maxX = points.map((p) => p.x).reduce(math.max);
    final minY = points.map((p) => p.y).reduce(math.min),
        maxY = points.map((p) => p.y).reduce(math.max);
    final scale = math
        .min(
          (size.width - 24) / math.max(1, maxX - minX),
          (size.height - 24) / math.max(1, maxY - minY),
        )
        .clamp(.001, 2.0);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      size.width / 2 - (minX + maxX) / 2 * scale,
      size.height / 2 - (minY + maxY) / 2 * scale,
    );
    canvas.scale(scale);
    for (final stroke in drawing.strokes) {
      paintStroke(canvas, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CanvasOverviewPainter old) => old.drawing != drawing;
}
