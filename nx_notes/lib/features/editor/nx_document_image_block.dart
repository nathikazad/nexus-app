part of 'nx_appflowy_blocks.dart';

class NxDocumentImageBlockComponentBuilder extends BlockComponentBuilder {
  NxDocumentImageBlockComponentBuilder({
    super.configuration,
    required this.deleteDocumentImage,
    required this.resolveDocumentImage,
    required this.documentImageBaseUrl,
  });

  final Future<void> Function(String url)? deleteDocumentImage;
  final String Function(String url)? resolveDocumentImage;
  final String? documentImageBaseUrl;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NxDocumentImageBlockComponentWidget(
      key: node.key,
      node: node,
      showActions: showActions(node),
      configuration: configuration,
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
      deleteDocumentImage: deleteDocumentImage,
      resolveDocumentImage: resolveDocumentImage,
      documentImageBaseUrl: documentImageBaseUrl,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

class NxDocumentImageBlockComponentWidget extends BlockComponentStatefulWidget {
  const NxDocumentImageBlockComponentWidget({
    required super.node,
    super.key,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.deleteDocumentImage,
    this.resolveDocumentImage,
    this.documentImageBaseUrl,
  });

  final Future<void> Function(String url)? deleteDocumentImage;
  final String Function(String url)? resolveDocumentImage;
  final String? documentImageBaseUrl;

  @override
  State<NxDocumentImageBlockComponentWidget> createState() =>
      _NxDocumentImageBlockComponentWidgetState();
}

class _NxDocumentImageBlockComponentWidgetState
    extends State<NxDocumentImageBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  final _imageKey = GlobalKey(debugLabel: ImageBlockKeys.type);
  late final editorState = Provider.of<EditorState>(context, listen: false);

  var _hovered = false;
  var _controlsPinned = false;
  var _deleting = false;
  double? _dragImageWidth;
  String? _lastLoggedSource;

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Widget build(BuildContext context) {
    final attributes = widget.node.attributes;
    final src = attributes[ImageBlockKeys.url]?.toString() ?? '';
    final resolvedSrc = widget.resolveDocumentImage?.call(src) ?? src;
    final alignment = AlignmentExtension.fromString(
      attributes[ImageBlockKeys.align] ?? 'center',
    );

    Widget child = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = _imageContentMaxWidth(context, constraints, padding);
        final displayWidth =
            _dragImageWidth ?? _imageWidthFromNode(widget.node, maxWidth);
        final showControls =
            editorState.editable && (_hovered || _controlsPinned || _deleting);
        _logRenderSource(src, resolvedSrc, displayWidth, maxWidth);

        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: editorState.editable
                ? () => setState(() => _controlsPinned = true)
                : null,
            child: Stack(
              key: _imageKey,
              children: <Widget>[
                Padding(
                  padding: padding,
                  child: _NxDebuggableImage(
                    key: ValueKey<String>(
                      '$resolvedSrc:${displayWidth.toStringAsFixed(1)}',
                    ),
                    src: resolvedSrc,
                    width: displayWidth,
                    height: null,
                    alignment: alignment,
                  ),
                ),
                if (showControls) ...<Widget>[
                  Positioned(
                    top: padding.top + 8,
                    right: padding.right + 8,
                    child: _NxImageDeleteButton(
                      deleting: _deleting,
                      onPressed: _delete,
                    ),
                  ),
                  Positioned(
                    right: padding.right + 4,
                    bottom: padding.bottom + 4,
                    child: _NxImageResizeHandle(
                      onPanUpdate: (details) => _resizeImage(details, maxWidth),
                      onPanEnd: (_) => _commitImageWidth(),
                      onPanCancel: _commitImageWidth,
                      onDoubleTap: () => _resetImageWidth(maxWidth),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    child = _wrapBlockSelection(
      node: widget.node,
      delegate: this,
      editorState: editorState,
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

  void _resizeImage(DragUpdateDetails details, double maxWidth) {
    final primaryDelta = details.delta.dx.abs() >= details.delta.dy.abs()
        ? details.delta.dx
        : details.delta.dy;
    setState(() {
      _dragImageWidth = _clampImageWidth(
        (_dragImageWidth ?? _imageWidthFromNode(widget.node, maxWidth)) +
            primaryDelta * 2,
        maxWidth,
      );
    });
  }

  void _commitImageWidth() {
    final width = _dragImageWidth;
    if (width == null) {
      return;
    }
    _saveImageWidth(width);
    setState(() => _dragImageWidth = null);
  }

  void _resetImageWidth(double maxWidth) {
    _saveImageWidth(maxWidth);
    setState(() => _dragImageWidth = null);
  }

  void _saveImageWidth(double width) {
    final maxWidth = _imageContentMaxWidthFromContext(context);
    final transaction = editorState.transaction
      ..updateNode(widget.node, <String, Object?>{
        ImageBlockKeys.width: _clampImageWidth(width, maxWidth),
      });
    editorState.apply(transaction);
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    final src = widget.node.attributes[ImageBlockKeys.url];
    try {
      if (src is String && widget.deleteDocumentImage != null) {
        await widget.deleteDocumentImage!(src);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not delete image file: $error')),
        );
      }
    } finally {
      _removeBlock();
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  void _removeBlock() {
    final transaction = editorState.transaction..deleteNode(widget.node);
    editorState.apply(transaction);
  }

  double _imageContentMaxWidthFromContext(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null
        ? MediaQuery.sizeOf(context).width
        : math.max(0, box.size.width - padding.horizontal);
  }

  void _logRenderSource(
    String storedSrc,
    String resolvedSrc,
    double width,
    double maxWidth,
  ) {
    final logKey = '$storedSrc->$resolvedSrc';
    if (_lastLoggedSource == logKey) {
      return;
    }
    _lastLoggedSource = logKey;
    _debugImageBlock(
      'render path=${widget.node.path} app_base=${Uri.base} '
      'image_base=${widget.documentImageBaseUrl ?? '(none)'} '
      'width=${width.toStringAsFixed(1)} max_width=${maxWidth.toStringAsFixed(1)} '
      'stored_src=${_describeImageSource(storedSrc)} '
      'resolved_src=${_describeImageSource(resolvedSrc)}',
    );
  }

  RenderBox? get _renderBox =>
      _imageKey.currentContext?.findRenderObject() as RenderBox?;

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
    final box = _renderBox;
    if (box == null) {
      return Rect.zero;
    }
    return Offset.zero & box.size;
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final box = _renderBox;
    if (box == null) {
      return <Rect>[];
    }
    return <Rect>[Offset.zero & box.size];
  }

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    return _renderBox?.localToGlobal(offset) ?? Offset.zero;
  }
}

class _NxDebuggableImage extends StatelessWidget {
  const _NxDebuggableImage({
    required this.src,
    required this.width,
    required this.height,
    required this.alignment,
    super.key,
  });

  final String src;
  final double width;
  final double? height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: math.max(_minDocumentImageWidth, width),
        height: height,
        child: _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (src.isEmpty) {
      _debugImageBlock('empty image source');
      return _NxImageErrorBox(width: width, message: 'Missing image URL');
    }

    final dataBytes = _imageBytesFromInlineSource(src);
    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        width: width,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          _debugImageBlock(
            'inline image failed error=$error src=${_describeImageSource(src)}',
          );
          return _NxImageErrorBox(
            width: width,
            message: 'Could not load image',
          );
        },
      );
    }

    if (_isNetworkImageSource(src)) {
      return Image.network(
        src,
        width: width,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _NxImageLoadingBox(width: width);
        },
        errorBuilder: (context, error, stackTrace) {
          _debugImageBlock(
            'network image failed app_base=${Uri.base} error=$error '
            'src=${_describeImageSource(src)}',
          );
          return _NxImageErrorBox(
            width: width,
            message: 'Could not load image',
          );
        },
      );
    }

    _debugImageBlock(
      'unsupported image source on ${kIsWeb ? 'web' : 'this renderer'} '
      'src=${_describeImageSource(src)}',
    );
    return _NxImageErrorBox(width: width, message: 'Unsupported image source');
  }
}

class _NxImageLoadingBox extends StatelessWidget {
  const _NxImageLoadingBox({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 120,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _NxImageErrorBox extends StatelessWidget {
  const _NxImageErrorBox({required this.width, required this.message});

  final double width;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 100),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}

class _NxImageDeleteButton extends StatelessWidget {
  const _NxImageDeleteButton({required this.deleting, required this.onPressed});

  final bool deleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.text,
      borderRadius: BorderRadius.circular(6),
      child: IconButton(
        tooltip: 'Delete image',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        onPressed: deleting ? null : onPressed,
        icon: deleting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.delete_outline, size: 16, color: Colors.white),
      ),
    );
  }
}

class _NxImageResizeHandle extends StatelessWidget {
  const _NxImageResizeHandle({
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    required this.onDoubleTap,
  });

  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback onPanCancel;
  final GestureTapCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpLeftDownRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        onPanCancel: onPanCancel,
        onDoubleTap: onDoubleTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Align(
            alignment: Alignment.bottomRight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
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

double _imageContentMaxWidth(
  BuildContext context,
  BoxConstraints constraints,
  EdgeInsets padding,
) {
  final fallback = MediaQuery.sizeOf(context).width;
  final width = constraints.maxWidth.isFinite ? constraints.maxWidth : fallback;
  return math.max(0, width - padding.horizontal);
}

double _imageWidthFromNode(Node node, double maxWidth) {
  return _clampImageWidth(
    _doubleValue(node.attributes[ImageBlockKeys.width], fallback: maxWidth),
    maxWidth,
  );
}

double _clampImageWidth(double width, double maxWidth) {
  final upper = math.max(_minDocumentImageWidth, maxWidth);
  return width.clamp(_minDocumentImageWidth, upper);
}

bool _isNetworkImageSource(String src) {
  final uri = Uri.tryParse(src);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

Uint8List? _imageBytesFromInlineSource(String src) {
  final dataUrl = RegExp(
    r'^data:image/[^;]+;base64,(.+)$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(src);
  final payload = dataUrl?.group(1) ?? src;
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

String _describeImageSource(String src) {
  final uri = Uri.tryParse(src);
  if (uri == null) {
    return 'invalid_uri raw_length=${src.length}';
  }
  if (uri.scheme == 'data') {
    return 'data_url length=${src.length}';
  }
  return 'scheme=${uri.scheme.isEmpty ? '(none)' : uri.scheme} '
      'host=${uri.host.isEmpty ? '(none)' : uri.host} '
      'port=${uri.hasPort ? uri.port : '(default)'} '
      'path=${uri.path} query=${uri.query}';
}

void _debugImageBlock(String message) {
  debugPrint('[nx_notes image] $message');
}

const _minDocumentImageWidth = 120.0;
