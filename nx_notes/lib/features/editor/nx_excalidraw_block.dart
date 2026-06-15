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
              child: const SizedBox(
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

class _ExcalidrawDialog extends StatefulWidget {
  const _ExcalidrawDialog({required this.initialScene, required this.onSave});

  final Map<String, dynamic> initialScene;
  final ValueChanged<Map<String, dynamic>> onSave;

  @override
  State<_ExcalidrawDialog> createState() => _ExcalidrawDialogState();
}

class _ExcalidrawDialogState extends State<_ExcalidrawDialog> {
  late Map<String, dynamic> _scene;
  late final TextEditingController _jsonController;
  var _saved = false;
  var _showJson = false;
  var _jsonDirty = false;
  String? _jsonError;
  var _frameSerial = 0;
  var _saveRequest = 0;

  @override
  void initState() {
    super.initState();
    _scene = Map<String, dynamic>.from(widget.initialScene);
    _jsonController = TextEditingController(text: _prettyJson(_scene));
    _jsonController.addListener(() {
      if (!_jsonDirty) {
        setState(() => _jsonDirty = true);
      }
    });
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.draw_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Excalidraw',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_saved)
                    const Text(
                      'Saved',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _toggleJson,
                    icon: const Icon(Icons.data_object, size: 17),
                    label: const Text('JSON'),
                    style: TextButton.styleFrom(
                      foregroundColor: _showJson
                          ? AppColors.text
                          : AppColors.muted,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _requestFrameSave,
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Done',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: NxExcalidrawEditorFrame(
                      key: ValueKey<int>(_frameSerial),
                      scene: _scene,
                      onSave: _saveScene,
                      saveRequest: _saveRequest,
                    ),
                  ),
                  if (_showJson)
                    _JsonSceneEditor(
                      controller: _jsonController,
                      dirty: _jsonDirty,
                      error: _jsonError,
                      onApply: _applyJson,
                      onRevert: _revertJson,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveScene(Map<String, dynamic> scene) {
    _scene = Map<String, dynamic>.from(scene);
    widget.onSave(_scene);
    _jsonController.text = _prettyJson(_scene);
    if (mounted) {
      setState(() {
        _saved = true;
        _jsonDirty = false;
        _jsonError = null;
      });
    }
  }

  void _toggleJson() {
    setState(() {
      _showJson = !_showJson;
      if (_showJson && !_jsonDirty) {
        _jsonController.text = _prettyJson(_scene);
      }
    });
  }

  void _requestFrameSave() {
    setState(() => _saveRequest += 1);
  }

  void _applyJson() {
    try {
      final decoded = jsonDecode(_jsonController.text);
      if (decoded is! Map) {
        throw const FormatException('Scene JSON must be an object.');
      }
      final scene = <String, dynamic>{
        ..._emptyExcalidrawScene(),
        ...Map<String, dynamic>.from(decoded),
      };
      _scene = scene;
      widget.onSave(_scene);
      _jsonController.text = _prettyJson(_scene);
      setState(() {
        _saved = true;
        _jsonDirty = false;
        _jsonError = null;
        _frameSerial += 1;
      });
    } catch (error) {
      setState(() => _jsonError = error.toString());
    }
  }

  void _revertJson() {
    _jsonController.text = _prettyJson(_scene);
    setState(() {
      _jsonDirty = false;
      _jsonError = null;
    });
  }
}

class _JsonSceneEditor extends StatelessWidget {
  const _JsonSceneEditor({
    required this.controller,
    required this.dirty,
    required this.error,
    required this.onApply,
    required this.onRevert,
  });

  final TextEditingController controller;
  final bool dirty;
  final String? error;
  final VoidCallback onApply;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: const BoxDecoration(
        color: Color(0xfffbfbfb),
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: <Widget>[
                const Text(
                  'Scene JSON',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: dirty ? onRevert : null,
                  child: const Text('Revert'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: dirty ? onApply : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.text,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.faint,
                    minimumSize: const Size(70, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.text,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Color(0xffa1a1aa)),
                  ),
                ),
              ),
            ),
          ),
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Text(
                error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffb91c1c),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExcalidrawPreview extends StatelessWidget {
  const _ExcalidrawPreview({required this.scene});

  final Map<String, dynamic> scene;

  @override
  Widget build(BuildContext context) {
    final elements = _excalidrawVisibleElements(scene);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffe4e4e7)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(
            painter: _ExcalidrawPreviewPainter(
              elements: elements,
              backgroundColor: _excalidrawBackgroundColor(scene),
            ),
            child: const SizedBox.expand(),
          ),
          if (elements.isEmpty)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xeefbfbfb),
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Click Open to draw',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExcalidrawPreviewPainter extends CustomPainter {
  const _ExcalidrawPreviewPainter({
    required this.elements,
    required this.backgroundColor,
  });

  final List<Map<String, dynamic>> elements;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
      background,
    );

    if (elements.isEmpty) {
      final stroke = Paint()
        ..color = AppColors.muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final center = size.center(Offset.zero);
      canvas.drawCircle(center, 22, stroke);
      canvas.drawLine(
        center.translate(-34, 28),
        center.translate(34, -28),
        stroke,
      );
      return;
    }

    final sceneBounds = _sceneBounds(elements);
    if (sceneBounds == null || sceneBounds.isEmpty) {
      return;
    }
    final viewport = Rect.fromLTWH(18, 18, size.width - 36, size.height - 36);
    final paddedBounds = sceneBounds.inflate(32);
    final scale = math.min(
      viewport.width / math.max(paddedBounds.width, 1),
      viewport.height / math.max(paddedBounds.height, 1),
    );
    final dx =
        viewport.left +
        (viewport.width - paddedBounds.width * scale) / 2 -
        paddedBounds.left * scale;
    final dy =
        viewport.top +
        (viewport.height - paddedBounds.height * scale) / 2 -
        paddedBounds.top * scale;

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
    );
    canvas.translate(dx, dy);
    canvas.scale(scale);
    for (final element in elements) {
      _drawElement(canvas, element);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ExcalidrawPreviewPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

void _drawElement(Canvas canvas, Map<String, dynamic> element) {
  final type = element['type'];
  final bounds = _elementBounds(element);
  if (bounds == null) {
    return;
  }

  canvas.save();
  final angle = _doubleAttribute(element, 'angle');
  if (angle != 0) {
    final center = bounds.center;
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..translate(-center.dx, -center.dy);
  }

  switch (type) {
    case 'rectangle':
      _drawRectangle(canvas, element, bounds);
    case 'ellipse':
      _drawEllipse(canvas, element, bounds);
    case 'diamond':
      _drawDiamond(canvas, element, bounds);
    case 'arrow':
      _drawLineElement(canvas, element, arrow: true);
    case 'line':
      _drawLineElement(canvas, element, arrow: false);
    case 'freedraw':
      _drawLineElement(canvas, element, arrow: false);
    case 'text':
      _drawTextElement(canvas, element);
    default:
      _drawRectangle(canvas, element, bounds);
  }

  canvas.restore();
}

void _drawRectangle(Canvas canvas, Map<String, dynamic> element, Rect bounds) {
  final fill = _fillPaint(element);
  final stroke = _strokePaint(element);
  final radius = Radius.circular(math.min(bounds.shortestSide / 6, 12));
  final rrect = RRect.fromRectAndRadius(bounds, radius);
  if (fill != null) {
    canvas.drawRRect(rrect, fill);
  }
  canvas.drawRRect(rrect, stroke);
}

void _drawEllipse(Canvas canvas, Map<String, dynamic> element, Rect bounds) {
  final fill = _fillPaint(element);
  final stroke = _strokePaint(element);
  if (fill != null) {
    canvas.drawOval(bounds, fill);
  }
  canvas.drawOval(bounds, stroke);
}

void _drawDiamond(Canvas canvas, Map<String, dynamic> element, Rect bounds) {
  final path = ui.Path()
    ..moveTo(bounds.center.dx, bounds.top)
    ..lineTo(bounds.right, bounds.center.dy)
    ..lineTo(bounds.center.dx, bounds.bottom)
    ..lineTo(bounds.left, bounds.center.dy)
    ..close();
  final fill = _fillPaint(element);
  if (fill != null) {
    canvas.drawPath(path, fill);
  }
  canvas.drawPath(path, _strokePaint(element));
}

void _drawLineElement(
  Canvas canvas,
  Map<String, dynamic> element, {
  required bool arrow,
}) {
  final points = _elementPoints(element);
  if (points.length < 2) {
    return;
  }
  final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  final stroke = _strokePaint(element)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(path, stroke);
  if (arrow) {
    _drawArrowHead(canvas, points, stroke);
  }
}

void _drawArrowHead(Canvas canvas, List<Offset> points, Paint stroke) {
  final end = points.last;
  var previous = points[points.length - 2];
  for (var i = points.length - 2; i >= 0; i--) {
    if ((end - points[i]).distance > 0.1) {
      previous = points[i];
      break;
    }
  }
  final angle = math.atan2(end.dy - previous.dy, end.dx - previous.dx);
  final length = math.max(12.0, stroke.strokeWidth * 4);
  const spread = math.pi / 7;
  final left = Offset(
    end.dx - length * math.cos(angle - spread),
    end.dy - length * math.sin(angle - spread),
  );
  final right = Offset(
    end.dx - length * math.cos(angle + spread),
    end.dy - length * math.sin(angle + spread),
  );
  canvas
    ..drawLine(end, left, stroke)
    ..drawLine(end, right, stroke);
}

void _drawTextElement(Canvas canvas, Map<String, dynamic> element) {
  final text = element['text'];
  if (text is! String || text.isEmpty) {
    return;
  }
  final x = _doubleAttribute(element, 'x');
  final y = _doubleAttribute(element, 'y');
  final width = _doubleAttribute(element, 'width', fallback: 220);
  final fontSize = _doubleAttribute(element, 'fontSize', fallback: 20);
  final color = _elementColor(element['strokeColor'], AppColors.text);
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0,
      ),
    ),
    maxLines: 6,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(width, fontSize * 2));
  painter.paint(canvas, Offset(x, y));
}

Paint _strokePaint(Map<String, dynamic> element) {
  final opacity = _doubleAttribute(element, 'opacity', fallback: 100) / 100;
  return Paint()
    ..color = _elementColor(
      element['strokeColor'],
      AppColors.text,
    ).withValues(alpha: opacity.clamp(0, 1))
    ..style = PaintingStyle.stroke
    ..strokeWidth = _doubleAttribute(element, 'strokeWidth', fallback: 2);
}

Paint? _fillPaint(Map<String, dynamic> element) {
  final background = element['backgroundColor'];
  if (background is! String ||
      background == 'transparent' ||
      background.trim().isEmpty) {
    return null;
  }
  final opacity = _doubleAttribute(element, 'opacity', fallback: 100) / 100;
  return Paint()
    ..color = _elementColor(
      background,
      Colors.transparent,
    ).withValues(alpha: opacity.clamp(0, 1))
    ..style = PaintingStyle.fill;
}

Rect? _sceneBounds(List<Map<String, dynamic>> elements) {
  Rect? bounds;
  for (final element in elements) {
    final elementBounds = _elementBounds(element);
    if (elementBounds == null) {
      continue;
    }
    bounds = bounds == null
        ? elementBounds
        : bounds.expandToInclude(elementBounds);
  }
  return bounds;
}

Rect? _elementBounds(Map<String, dynamic> element) {
  final type = element['type'];
  if (type == 'arrow' || type == 'line' || type == 'freedraw') {
    final points = _elementPoints(element);
    if (points.isEmpty) {
      return null;
    }
    var left = points.first.dx;
    var right = points.first.dx;
    var top = points.first.dy;
    var bottom = points.first.dy;
    for (final point in points.skip(1)) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(
      left,
      top,
      right,
      bottom,
    ).inflate(_doubleAttribute(element, 'strokeWidth', fallback: 2) + 8);
  }

  final x = _doubleAttribute(element, 'x');
  final y = _doubleAttribute(element, 'y');
  final width = _doubleAttribute(element, 'width');
  final height = _doubleAttribute(element, 'height');
  return Rect.fromLTRB(
    math.min(x, x + width),
    math.min(y, y + height),
    math.max(x, x + width),
    math.max(y, y + height),
  );
}

List<Offset> _elementPoints(Map<String, dynamic> element) {
  final x = _doubleAttribute(element, 'x');
  final y = _doubleAttribute(element, 'y');
  final rawPoints = element['points'];
  if (rawPoints is! List || rawPoints.isEmpty) {
    final width = _doubleAttribute(element, 'width');
    final height = _doubleAttribute(element, 'height');
    return <Offset>[Offset(x, y), Offset(x + width, y + height)];
  }
  return <Offset>[
    for (final point in rawPoints)
      if (point is List && point.length >= 2)
        Offset(x + _doubleValue(point[0]), y + _doubleValue(point[1])),
  ];
}

List<Map<String, dynamic>> _excalidrawVisibleElements(
  Map<String, dynamic> scene,
) {
  final elements = scene['elements'];
  if (elements is! List) {
    return const <Map<String, dynamic>>[];
  }
  return <Map<String, dynamic>>[
    for (final element in elements)
      if (element is Map && element['isDeleted'] != true)
        Map<String, dynamic>.from(element),
  ];
}

Color _excalidrawBackgroundColor(Map<String, dynamic> scene) {
  final appState = scene['appState'];
  if (appState is Map) {
    return _elementColor(
      appState['viewBackgroundColor'],
      const Color(0xfffbfbfb),
    );
  }
  return const Color(0xfffbfbfb);
}

Color _elementColor(Object? value, Color fallback) {
  if (value is! String) {
    return fallback;
  }
  final normalized = value.trim();
  if (!normalized.startsWith('#')) {
    return fallback;
  }
  final hex = normalized.substring(1);
  if (hex.length == 3) {
    final expanded = hex.split('').map((char) => '$char$char').join();
    return Color(int.parse('ff$expanded', radix: 16));
  }
  if (hex.length == 6) {
    return Color(int.parse('ff$hex', radix: 16));
  }
  if (hex.length == 8) {
    return Color(int.parse(hex, radix: 16));
  }
  return fallback;
}

double _doubleAttribute(
  Map<String, dynamic> element,
  String key, {
  double fallback = 0,
}) {
  return _doubleValue(element[key], fallback: fallback);
}

double _doubleValue(Object? value, {double fallback = 0}) {
  return switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

Map<String, dynamic> _emptyExcalidrawScene() {
  return <String, dynamic>{
    'type': 'excalidraw',
    'version': 2,
    'source': 'nx_notes',
    'elements': <dynamic>[],
    'appState': <String, dynamic>{'viewBackgroundColor': '#ffffff'},
    'files': <String, dynamic>{},
  };
}

String _prettyJson(Map<String, dynamic> scene) {
  return const JsonEncoder.withIndent('  ').convert(scene);
}

const _defaultExcalidrawPreviewHeight = 190.0;
const _minExcalidrawPreviewHeight = 120.0;
const _maxExcalidrawPreviewHeight = 620.0;

double _excalidrawPreviewHeightFromNode(Node node) {
  return _clampExcalidrawPreviewHeight(
    _doubleValue(
      node.attributes['preview_height'],
      fallback: _defaultExcalidrawPreviewHeight,
    ),
  );
}

double _clampExcalidrawPreviewHeight(double height) {
  return height.clamp(_minExcalidrawPreviewHeight, _maxExcalidrawPreviewHeight);
}

Map<String, dynamic> _excalidrawSceneFromNode(Node node) {
  final scene = node.attributes['scene'];
  if (scene is Map) {
    return <String, dynamic>{
      ..._emptyExcalidrawScene(),
      ...Map<String, dynamic>.from(scene),
    };
  }
  return _emptyExcalidrawScene();
}
