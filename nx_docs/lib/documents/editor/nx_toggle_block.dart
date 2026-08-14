part of 'nx_appflowy_blocks.dart';

Node nxToggleNode() {
  return Node(
    type: nxToggleBlockType,
    attributes: <String, Object>{
      blockComponentDelta: (Delta()..insert('Toggle heading')).toJson(),
      'collapsed': false,
    },
    children: <Node>[
      paragraphNode(text: 'Nested toggle content. Type / to add blocks here.'),
    ],
  );
}

class NxToggleBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NxToggleBlockComponentWidget(
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
      (node) => true;
}

class NxToggleBlockComponentWidget extends BlockComponentStatefulWidget {
  const NxToggleBlockComponentWidget({
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
  State<NxToggleBlockComponentWidget> createState() =>
      _NxToggleBlockComponentWidgetState();
}

class _NxToggleBlockComponentWidgetState
    extends State<NxToggleBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'nx_toggle_title');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: nxToggleBlockType,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = _boolAttribute(widget.node, 'collapsed', false);
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed || widget.node.children.isEmpty) {
      return buildComponent(context, withBackgroundColor: true);
    }
    return buildComponentWithChildren(context);
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    Widget child = Padding(
      key: blockComponentKey,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      _collapsed
                          ? Icons.keyboard_arrow_right
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: widget.node.delta == null
                      ? Text(
                          _stringAttribute(
                            widget.node,
                            'title',
                            'Toggle heading',
                          ),
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        )
                      : AppFlowyRichText(
                          key: forwardKey,
                          delegate: this,
                          node: widget.node,
                          editorState: widget.editorState,
                          cursorColor:
                              widget.editorState.editorStyle.cursorColor,
                          selectionColor:
                              widget.editorState.editorStyle.selectionColor,
                          cursorWidth:
                              widget.editorState.editorStyle.cursorWidth,
                          placeholderText: 'Toggle heading',
                          textSpanDecorator: (textSpan) =>
                              textSpan.updateTextStyle(
                                TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                          placeholderTextSpanDecorator: (textSpan) =>
                              textSpan.updateTextStyle(
                                TextStyle(
                                  color: AppColors.faint,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                        ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Add nested block',
                  onPressed: _addNestedParagraph,
                  icon: Icon(Icons.add, size: 16, color: AppColors.faint),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
            if (_collapsed && widget.node.children.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(
                  '${widget.node.children.length} nested block${widget.node.children.length == 1 ? '' : 's'} hidden',
                  style: TextStyle(
                    color: AppColors.faint,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (widget.node.delta == null &&
                !_collapsed &&
                _stringAttribute(widget.node, 'body', '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(
                  _stringAttribute(widget.node, 'body', ''),
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (withBackgroundColor) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.sidebar,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      );
    }
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

  @override
  Widget buildComponentWithChildren(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: NestedListWidget(
        indentPadding: const EdgeInsets.only(left: 28),
        child: buildComponent(context, withBackgroundColor: false),
        children: widget.editorState.renderer.buildList(
          context,
          widget.node.children,
        ),
      ),
    );
  }

  void _toggle() {
    final nextCollapsed = !_collapsed;
    setState(() {
      _collapsed = nextCollapsed;
    });
    final transaction = widget.editorState.transaction
      ..updateNode(widget.node, <String, Object>{'collapsed': nextCollapsed});
    widget.editorState.apply(transaction);
  }

  void _addNestedParagraph() {
    final transaction = widget.editorState.transaction
      ..insertNode(
        widget.node.path.child(widget.node.children.length),
        paragraphNode(text: ''),
      );
    widget.editorState.apply(transaction);
    if (_collapsed) {
      setState(() {
        _collapsed = false;
      });
      final collapseTransaction = widget.editorState.transaction
        ..updateNode(widget.node, const <String, Object>{'collapsed': false});
      widget.editorState.apply(collapseTransaction);
    }
  }
}
