import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

const String nxToggleBlockType = 'nx_toggle';
const String nxBlogLinkBlockType = 'nx_blog_link';

Map<String, BlockComponentBuilder> nxBlockComponentBuilders() {
  final builders = <String, BlockComponentBuilder>{
    ...standardBlockComponentBuilderMap,
    nxToggleBlockType: NxToggleBlockComponentBuilder(),
    nxBlogLinkBlockType: NxBlogLinkBlockComponentBuilder(),
  };
  for (final entry in builders.entries) {
    if (entry.key == PageBlockKeys.type) {
      continue;
    }
    final builder = entry.value;
    builder.showActions = (_) => true;
    builder.actionBuilder = (context, _) {
      return NxDragToReorderAction(
        blockComponentContext: context,
        builder: builder,
      );
    };
  }
  return builders;
}

CharacterShortcutEvent nxSlashCommand() {
  return CharacterShortcutEvent(
    key: 'show nx slash menu',
    character: '/',
    handler: (editorState) async {
      final selection = editorState.selection;
      if (selection == null || !selection.isCollapsed) {
        return false;
      }
      final node = editorState.getNodeAtPath(selection.start.path);
      if (node == null || node.delta == null) {
        return false;
      }
      await editorState.insertTextAtPosition('/', position: selection.start);
      final context = node.context;
      if (context == null || !context.mounted) {
        return true;
      }
      _showNxSlashOverlay(context, editorState);
      return true;
    },
  );
}

List<SelectionMenuItem> _nxStaticSelectionMenuItems() {
  return <SelectionMenuItem>[
    SelectionMenuItem.node(
      getName: () => 'Toggle',
      keywords: const <String>['toggle', 'details', 'collapse'],
      iconData: Icons.expand_circle_down_outlined,
      nodeBuilder: (_, __) => nxToggleNode(),
      replace: _replaceCurrentParagraph,
    ),
    ...standardSelectionMenuItems,
  ];
}

void _showNxSlashOverlay(BuildContext anchorContext, EditorState editorState) {
  final overlay = Overlay.of(anchorContext);
  final renderBox = anchorContext.findRenderObject() as RenderBox?;
  final anchor = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
  late final OverlayEntry entry;
  late final _NxSelectionMenuService menuService;
  entry = OverlayEntry(
    builder: (context) {
      menuService = _NxSelectionMenuService(
        entry: entry,
        style: SelectionMenuStyle.light,
      );
      return Positioned(
        left: anchor.dx + 8,
        top: anchor.dy + 28,
        child: NxSlashMenuOverlay(
          editorState: editorState,
          menuService: menuService,
          onDismiss: () {
            if (entry.mounted) {
              entry.remove();
            }
          },
        ),
      );
    },
  );
  overlay.insert(entry);
}

class NxSlashMenuOverlay extends StatefulWidget {
  const NxSlashMenuOverlay({
    required this.editorState,
    required this.menuService,
    required this.onDismiss,
    super.key,
  });

  final EditorState editorState;
  final SelectionMenuService menuService;
  final VoidCallback onDismiss;

  @override
  State<NxSlashMenuOverlay> createState() => _NxSlashMenuOverlayState();
}

class _NxSlashMenuOverlayState extends State<NxSlashMenuOverlay> {
  final _focusNode = FocusNode(debugLabel: 'nx_slash_menu');
  final _staticItems = _nxStaticSelectionMenuItems();
  var _keyword = '';
  var _selectedIndex = 0;
  var _loadingBlogs = false;
  var _blogRequestId = 0;
  List<_FakeBlogDocument> _blogResults = const <_FakeBlogDocument>[];

  @override
  void initState() {
    super.initState();
    for (final item in _staticItems) {
      item.onSelected = widget.onDismiss;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 300,
              maxWidth: 340,
              maxHeight: 320,
            ),
            child: _loadingBlogs
                ? const _NxSlashMessage(text: 'Loading blogs...')
                : rows.isEmpty
                ? const _NxSlashMessage(text: 'No results')
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      return rows[index].build(
                        context,
                        selected: index == _selectedIndex,
                        editorState: widget.editorState,
                        style: widget.menuService.style,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  List<_NxSlashRow> get _rows {
    if (_keyword.startsWith('blog/')) {
      return <_NxSlashRow>[
        for (final blog in _blogResults)
          _NxBlogResultRow(blog: blog, onSelected: () => _selectBlog(blog)),
      ];
    }

    final lowerKeyword = _keyword.toLowerCase();
    final rows = <_NxSlashRow>[
      if ('blog'.contains(lowerKeyword))
        _NxBlogCommandRow(onSelected: _enterBlogSearch),
      for (final item in _staticItems)
        if (lowerKeyword.isEmpty ||
            item.allKeywords.any((keyword) => keyword.contains(lowerKeyword)))
          _NxSelectionItemRow(
            item: item,
            onSelected: () => _selectStaticItem(item),
          ),
    ];
    return rows;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) {
      return KeyEventResult.skipRemainingHandlers;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final rows = _rows;
      if (rows.isNotEmpty && _selectedIndex < rows.length) {
        rows[_selectedIndex].select();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_keyword.isEmpty) {
        widget.onDismiss();
      } else {
        _deleteLastCharacter();
        setState(() {
          _keyword = _keyword.substring(0, _keyword.length - 1);
          _selectedIndex = 0;
        });
        _maybeFetchBlogs();
      }
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null &&
        character.isNotEmpty &&
        event.logicalKey != LogicalKeyboardKey.tab) {
      _insertText(character);
      setState(() {
        _keyword += character;
        _selectedIndex = 0;
      });
      _maybeFetchBlogs();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveSelection(int delta) {
    final rows = _rows;
    if (rows.isEmpty) {
      return;
    }
    setState(() {
      _selectedIndex = (_selectedIndex + delta) % rows.length;
      if (_selectedIndex < 0) {
        _selectedIndex = rows.length - 1;
      }
    });
  }

  void _enterBlogSearch() {
    final start = _keyword.length > 5 ? 5 : _keyword.length;
    final missing = 'blog/'.substring(start);
    if (missing.isNotEmpty) {
      _insertText(missing);
    }
    setState(() {
      _keyword = 'blog/';
      _selectedIndex = 0;
    });
    _maybeFetchBlogs();
  }

  void _maybeFetchBlogs() {
    if (!_keyword.startsWith('blog/')) {
      setState(() {
        _loadingBlogs = false;
        _blogResults = const <_FakeBlogDocument>[];
      });
      return;
    }
    final requestId = ++_blogRequestId;
    final query = _keyword.substring('blog/'.length);
    setState(() {
      _loadingBlogs = true;
      _blogResults = const <_FakeBlogDocument>[];
    });
    _fetchBlogDocuments(query).then((blogs) {
      if (!mounted || requestId != _blogRequestId) {
        return;
      }
      setState(() {
        _loadingBlogs = false;
        _blogResults = blogs;
        _selectedIndex = 0;
      });
    });
  }

  void _selectStaticItem(SelectionMenuItem item) {
    item.handler(widget.editorState, widget.menuService, context);
  }

  void _selectBlog(_FakeBlogDocument blog) {
    _deleteSlashKeywordAndInsertBlogLink(blog);
    widget.onDismiss();
  }

  void _insertText(String text) {
    final selection = widget.editorState.selection;
    if (selection == null || !selection.isSingle) {
      return;
    }
    final node = widget.editorState.getNodeAtPath(selection.end.path);
    if (node == null) {
      return;
    }
    final transaction = widget.editorState.transaction
      ..insertText(node, selection.end.offset, text);
    widget.editorState.apply(transaction);
  }

  void _deleteLastCharacter() {
    final selection = widget.editorState.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }
    final node = widget.editorState.getNodeAtPath(selection.end.path);
    if (node == null || node.delta == null || selection.start.offset == 0) {
      return;
    }
    final transaction = widget.editorState.transaction
      ..deleteText(node, selection.start.offset - 1, 1);
    widget.editorState.apply(transaction);
  }

  void _deleteSlashKeywordAndInsertBlogLink(_FakeBlogDocument blog) {
    final selection = widget.editorState.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }
    final node = widget.editorState.getNodeAtPath(selection.end.path);
    final plainText = node?.delta?.toPlainText();
    if (node == null || plainText == null) {
      return;
    }
    final end = selection.start.offset;
    final slashIndex = plainText.substring(0, end).lastIndexOf('/');
    if (slashIndex == -1) {
      return;
    }
    final href = '/blog/${blog.id}';
    final needsLeadingSpace =
        slashIndex > 0 &&
        plainText.substring(0, slashIndex).trimRight().length == slashIndex;
    final needsTrailingSpace =
        end == plainText.length || plainText.substring(end).startsWith(' ');
    final transaction = widget.editorState.transaction;
    transaction.deleteText(node, slashIndex, end - slashIndex);
    var insertIndex = slashIndex;
    if (needsLeadingSpace) {
      transaction.insertText(node, insertIndex, ' ', sliceAttributes: false);
      insertIndex += 1;
    }
    transaction.insertText(
      node,
      insertIndex,
      blog.title,
      attributes: <String, dynamic>{BuiltInAttributeKey.href: href},
      sliceAttributes: false,
    );
    insertIndex += blog.title.length;
    if (needsTrailingSpace) {
      transaction.insertText(node, insertIndex, ' ', sliceAttributes: false);
    }
    widget.editorState.apply(transaction);
  }
}

abstract class _NxSlashRow {
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  });

  void select();
}

class _NxBlogCommandRow implements _NxSlashRow {
  const _NxBlogCommandRow({required this.onSelected});

  final VoidCallback onSelected;

  @override
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  }) {
    return _NxSlashTile(
      selected: selected,
      icon: Icons.article_outlined,
      title: 'Blog',
      subtitle: 'Search blog documents',
      onTap: onSelected,
    );
  }

  @override
  void select() => onSelected();
}

class _NxBlogResultRow implements _NxSlashRow {
  const _NxBlogResultRow({required this.blog, required this.onSelected});

  final _FakeBlogDocument blog;
  final VoidCallback onSelected;

  @override
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  }) {
    return _NxSlashTile(
      selected: selected,
      icon: Icons.article_outlined,
      title: blog.title,
      subtitle: blog.excerpt,
      trailing: blog.status,
      onTap: onSelected,
    );
  }

  @override
  void select() => onSelected();
}

class _NxSelectionItemRow implements _NxSlashRow {
  const _NxSelectionItemRow({required this.item, required this.onSelected});

  final SelectionMenuItem item;
  final VoidCallback onSelected;

  @override
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  }) {
    return _NxSlashTile(
      selected: selected,
      leading: item.icon(editorState, selected, style),
      title: item.name,
      onTap: onSelected,
    );
  }

  @override
  void select() => onSelected();
}

class _NxSlashTile extends StatelessWidget {
  const _NxSlashTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
  });

  final bool selected;
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.subtle : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Center(
                  child:
                      leading ?? Icon(icon, size: 18, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 9),
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
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: AppColors.faint,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NxSlashMessage extends StatelessWidget {
  const _NxSlashMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}

class _NxSelectionMenuService implements SelectionMenuService {
  _NxSelectionMenuService({required this.entry, required this.style});

  final OverlayEntry entry;

  @override
  final SelectionMenuStyle style;

  @override
  Offset get offset => Offset.zero;

  @override
  Alignment get alignment => Alignment.topLeft;

  @override
  void dismiss() {
    if (entry.mounted) {
      entry.remove();
    }
  }

  @override
  (double? left, double? top, double? right, double? bottom) getPosition() {
    return (null, null, null, null);
  }

  @override
  Future<void> show() async {}
}

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

String nxPlainTextForCustomNode(Node node) {
  switch (node.type) {
    case nxToggleBlockType:
      final title = node.delta?.toPlainText().trim().isNotEmpty == true
          ? node.delta!.toPlainText().trim()
          : _stringAttribute(node, 'title', 'Toggle heading');
      return title;
    case nxBlogLinkBlockType:
      final title = _stringAttribute(node, 'title', 'Blog document');
      return 'Blog: $title';
    default:
      return '';
  }
}

bool _replaceCurrentParagraph(EditorState editorState, Node node) {
  return node.type == ParagraphBlockKeys.type &&
      (node.delta?.toPlainText().trim().isEmpty ?? false);
}

String _stringAttribute(Node node, String key, String fallback) {
  final value = node.attributes[key];
  return value is String ? value : fallback;
}

bool _boolAttribute(Node node, String key, bool fallback) {
  final value = node.attributes[key];
  return value is bool ? value : fallback;
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
                          style: const TextStyle(
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
                                const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                          placeholderTextSpanDecorator: (textSpan) =>
                              textSpan.updateTextStyle(
                                const TextStyle(
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
                  icon: const Icon(Icons.add, size: 16, color: AppColors.faint),
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
                  style: const TextStyle(
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
                  style: const TextStyle(
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

Widget _wrapBlockSelection({
  required Node node,
  required SelectableMixin delegate,
  required EditorState editorState,
  required Widget child,
}) {
  return BlockSelectionContainer(
    node: node,
    delegate: delegate,
    listenable: editorState.selectionNotifier,
    remoteSelection: editorState.remoteSelections,
    blockColor: editorState.editorStyle.selectionColor,
    supportTypes: const <BlockSelectionType>[BlockSelectionType.block],
    child: child,
  );
}

class _FakeBlogDocument {
  const _FakeBlogDocument({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.status,
    required this.keywords,
  });

  final String id;
  final String title;
  final String excerpt;
  final String status;
  final List<String> keywords;
}

const List<_FakeBlogDocument> _fakeBlogDocuments = <_FakeBlogDocument>[
  _FakeBlogDocument(
    id: 'blog_001',
    title: 'Designing Quiet Internal Tools',
    excerpt: 'A short essay on density, restraint, and fast scanning.',
    status: 'Draft',
    keywords: <String>['design', 'internal', 'tools', 'ui'],
  ),
  _FakeBlogDocument(
    id: 'blog_002',
    title: 'KGQL Notes Architecture',
    excerpt: 'How essays, tags, snapshots, and links fit together.',
    status: 'Published',
    keywords: <String>['kgql', 'notes', 'architecture'],
  ),
  _FakeBlogDocument(
    id: 'blog_003',
    title: 'Mobile Editor Constraints',
    excerpt: 'Keyboard, toolbar, viewport, and one-document navigation rules.',
    status: 'Review',
    keywords: <String>['mobile', 'editor', 'keyboard'],
  ),
  _FakeBlogDocument(
    id: 'blog_004',
    title: 'Version History for Essays',
    excerpt: 'Whole-document snapshots, latest state, and restore behavior.',
    status: 'Draft',
    keywords: <String>['version', 'history', 'snapshot'],
  ),
];

Future<List<_FakeBlogDocument>> _fetchBlogDocuments(String query) async {
  await Future<void>.delayed(const Duration(milliseconds: 280));
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return _fakeBlogDocuments;
  }
  return _fakeBlogDocuments
      .where((blog) {
        return <String>[
          blog.title,
          blog.excerpt,
          blog.status,
          ...blog.keywords,
        ].join(' ').toLowerCase().contains(normalized);
      })
      .toList(growable: false);
}

enum _DropVerticalPosition { top, bottom }

class NxDragToReorderAction extends StatefulWidget {
  const NxDragToReorderAction({
    required this.blockComponentContext,
    required this.builder,
    super.key,
  });

  final BlockComponentContext blockComponentContext;
  final BlockComponentBuilder builder;

  @override
  State<NxDragToReorderAction> createState() => _NxDragToReorderActionState();
}

const String _reorderInterceptorKey = 'nx_notes_drag_to_reorder';

class _NxDragToReorderActionState extends State<NxDragToReorderAction> {
  late final EditorState editorState = context.read<EditorState>();
  late final Node feedbackNode;
  late final BlockComponentContext feedbackContext;
  Offset? _globalPosition;
  Selection? _beforeSelection;

  late final SelectionGestureInterceptor _gestureInterceptor =
      SelectionGestureInterceptor(
        key: _reorderInterceptorKey,
        canTap: (details) => !_isTapInBounds(details.globalPosition),
      );

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  void initState() {
    super.initState();
    editorState.service.selectionService.registerGestureInterceptor(
      _gestureInterceptor,
    );
    feedbackNode = widget.blockComponentContext.node.copyWith();
    feedbackContext = BlockComponentContext(
      widget.blockComponentContext.buildContext,
      feedbackNode,
    );
  }

  @override
  void dispose() {
    editorState.service.selectionService.unregisterGestureInterceptor(
      _reorderInterceptorKey,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, right: 4),
      child: Draggable<Node>(
        data: feedbackNode,
        feedback: _buildFeedback(),
        onDragStarted: editorState.selectionService.removeDropTarget,
        onDragUpdate: (details) {
          editorState.selectionService.renderDropTargetForOffset(
            details.globalPosition,
            builder: (context, data) => _buildDropArea(
              context,
              data,
              widget.blockComponentContext.node,
            ),
          );
          _globalPosition = details.globalPosition;
          editorState.scrollService?.startAutoScroll(details.globalPosition);
        },
        onDragEnd: (_) {
          editorState.selectionService.removeDropTarget();
          final position = _globalPosition;
          _globalPosition = null;
          if (position == null) {
            return;
          }
          final data = editorState.selectionService.getDropTargetRenderData(
            position,
          );
          _moveNodeToNewPosition(
            widget.blockComponentContext.node,
            data?.cursorNode?.path,
            position,
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _selectBlock,
          child: const MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: AppColors.faint,
            ),
          ),
        ),
      ),
    );
  }

  void _selectBlock() {
    final path = widget.blockComponentContext.node.path;
    if (_beforeSelection != null && path.inSelection(_beforeSelection)) {
      editorState.updateSelectionWithReason(
        _beforeSelection,
        customSelectionType: SelectionType.block,
      );
      return;
    }
    editorState.updateSelectionWithReason(
      Selection.collapsed(Position(path: path)),
      customSelectionType: SelectionType.block,
    );
  }

  bool _isTapInBounds(Offset offset) {
    final renderBox = _renderBox;
    if (renderBox == null) {
      return false;
    }
    final result = renderBox.paintBounds.contains(
      renderBox.globalToLocal(offset),
    );
    _beforeSelection = result ? editorState.selection : null;
    return result;
  }

  void _moveNodeToNewPosition(
    Node node,
    Path? acceptedPath,
    Offset dragOffset,
  ) {
    if (acceptedPath == null) {
      return;
    }
    final targetNode = editorState.getNodeAtPath(acceptedPath);
    if (targetNode == null) {
      return;
    }
    final position = _getPosition(targetNode, dragOffset);
    if (position == null) {
      return;
    }
    final (verticalPosition, _) = position;
    final newPath = verticalPosition == _DropVerticalPosition.bottom
        ? targetNode.path.next
        : targetNode.path;
    if (_shouldIgnoreDrop(node, newPath)) {
      return;
    }
    final transaction = editorState.transaction..moveNode(newPath, node);
    editorState.apply(transaction);
  }

  Widget _buildFeedback() {
    final child = IntrinsicWidth(
      child: IntrinsicHeight(
        child: Provider.value(
          value: editorState,
          child: widget.builder.build(feedbackContext),
        ),
      ),
    );

    return Opacity(
      opacity: 0.72,
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

Widget _buildDropArea(
  BuildContext context,
  DragAreaBuilderData data,
  Node dragNode,
) {
  final targetNode = data.targetNode;
  if (_shouldIgnoreDrop(dragNode, targetNode.path)) {
    return const SizedBox.shrink();
  }

  final position = _getPosition(targetNode, data.dragOffset);
  if (position == null) {
    return const SizedBox.shrink();
  }
  final (verticalPosition, globalBlockRect) = position;

  return Positioned(
    top: verticalPosition == _DropVerticalPosition.top
        ? globalBlockRect.top
        : globalBlockRect.bottom,
    left: globalBlockRect.left + 22,
    child: Container(
      height: 2,
      width: globalBlockRect.width - 22,
      color: AppColors.blue,
    ),
  );
}

(_DropVerticalPosition, Rect)? _getPosition(
  Node targetNode,
  Offset dragOffset,
) {
  final selectable = targetNode.selectable;
  final renderBox = selectable?.context.findRenderObject() as RenderBox?;
  if (selectable == null || renderBox == null) {
    return null;
  }

  final globalBlockOffset = renderBox.localToGlobal(Offset.zero);
  final globalBlockRect = globalBlockOffset & renderBox.size;
  if (!globalBlockRect.contains(dragOffset)) {
    return null;
  }

  final verticalPosition =
      dragOffset.dy < globalBlockRect.top + globalBlockRect.height / 2
      ? _DropVerticalPosition.top
      : _DropVerticalPosition.bottom;
  return (verticalPosition, globalBlockRect);
}

bool _shouldIgnoreDrop(Node dragNode, Path? targetPath) {
  if (targetPath == null) {
    return true;
  }
  if (dragNode.path.equals(targetPath)) {
    return true;
  }
  if (dragNode.path.isAncestorOf(targetPath)) {
    return true;
  }
  return false;
}
