part of 'nx_appflowy_blocks.dart';

class NxBlogLinkBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NxBlogLinkBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.children.isEmpty;
}

class NxBlogLinkBlockComponentWidget extends BlockComponentStatefulWidget {
  const NxBlogLinkBlockComponentWidget({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
  });

  @override
  State<NxBlogLinkBlockComponentWidget> createState() =>
      _NxBlogLinkBlockComponentWidgetState();
}

class _NxBlogLinkBlockComponentWidgetState
    extends State<NxBlogLinkBlockComponentWidget>
    with SelectableMixin {
  final _blockKey = GlobalKey(debugLabel: nxBlogLinkBlockType);

  @override
  Widget build(BuildContext context) {
    final title = _stringAttribute(widget.node, 'title', 'Blog document');
    final excerpt = _stringAttribute(widget.node, 'excerpt', '');
    final status = _stringAttribute(widget.node, 'status', 'Draft');
    Widget child = Padding(
      key: _blockKey,
      padding: const EdgeInsets.symmetric(vertical: 5),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.subtle,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (excerpt.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                status,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final editorState = context.read<EditorState>();
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
