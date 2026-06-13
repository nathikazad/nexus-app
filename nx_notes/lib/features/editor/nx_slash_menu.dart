part of 'nx_appflowy_blocks.dart';

CharacterShortcutEvent nxSlashCommand({
  required Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels,
  required Future<LinkedModel> Function(String title) createLinkedEssay,
  required Future<void> Function(LinkableModelType modelType, LinkedModel model)
  onLinkableModelSelected,
}) {
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
      _showNxSlashOverlay(
        context,
        editorState,
        searchLinkableModels: searchLinkableModels,
        createLinkedEssay: createLinkedEssay,
        onLinkableModelSelected: onLinkableModelSelected,
      );
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

void _showNxSlashOverlay(
  BuildContext anchorContext,
  EditorState editorState, {
  required Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels,
  required Future<LinkedModel> Function(String title) createLinkedEssay,
  required Future<void> Function(LinkableModelType modelType, LinkedModel model)
  onLinkableModelSelected,
}) {
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
          searchLinkableModels: searchLinkableModels,
          createLinkedEssay: createLinkedEssay,
          onLinkableModelSelected: onLinkableModelSelected,
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
    required this.searchLinkableModels,
    required this.createLinkedEssay,
    required this.onLinkableModelSelected,
    required this.onDismiss,
    super.key,
  });

  final EditorState editorState;
  final SelectionMenuService menuService;
  final Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels;
  final Future<LinkedModel> Function(String title) createLinkedEssay;
  final Future<void> Function(LinkableModelType modelType, LinkedModel model)
  onLinkableModelSelected;
  final VoidCallback onDismiss;

  @override
  State<NxSlashMenuOverlay> createState() => _NxSlashMenuOverlayState();
}

class _NxSlashMenuOverlayState extends State<NxSlashMenuOverlay> {
  final _focusNode = FocusNode(debugLabel: 'nx_slash_menu');
  final _staticItems = _nxStaticSelectionMenuItems();
  var _keyword = '';
  var _selectedIndex = 0;
  var _loadingLinkableModels = false;
  var _linkableRequestId = 0;
  List<LinkedModel> _linkableResults = const <LinkedModel>[];

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
            child: _loadingLinkableModels
                ? const _NxSlashMessage(text: 'Loading models...')
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
    final selectedType = _selectedLinkableType;
    if (selectedType != null) {
      return <_NxSlashRow>[
        if (selectedType == LinkableModelType.essay)
          _NxLinkableModelResultRow(
            icon: Icons.add,
            title: 'Create "$_linkableQueryTitle"',
            subtitle: 'New essay',
            onSelected: () => _createAndSelectEssay(_linkableQueryTitle),
          ),
        for (final model in _linkableResults)
          _NxLinkableModelResultRow(
            model: model,
            onSelected: () => _selectLinkableModel(selectedType, model),
          ),
      ];
    }

    final lowerKeyword = _keyword.toLowerCase();
    final rows = <_NxSlashRow>[
      for (final type in LinkableModelType.values)
        if (lowerKeyword.isEmpty ||
            type.command.contains(lowerKeyword) ||
            type.kgqlName.toLowerCase().contains(lowerKeyword))
          _NxLinkableModelCommandRow(
            modelType: type,
            onSelected: () => _enterLinkableModelSearch(type),
          ),
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

  LinkableModelType? get _selectedLinkableType {
    final slashIndex = _keyword.indexOf('/');
    if (slashIndex <= 0) {
      return null;
    }
    return LinkableModelType.fromCommand(_keyword.substring(0, slashIndex));
  }

  String get _linkableQuery {
    final modelType = _selectedLinkableType;
    if (modelType == null) return '';
    return _keyword.substring(modelType.command.length + 1);
  }

  String get _linkableQueryTitle {
    final query = _linkableQuery.trim();
    return query.isEmpty ? 'Untitled essay' : query;
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
        _maybeFetchLinkableModels();
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
      _maybeFetchLinkableModels();
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

  void _enterLinkableModelSearch(LinkableModelType modelType) {
    final command = '${modelType.command}/';
    final start = _keyword.length > command.length
        ? command.length
        : _keyword.length;
    final missing = command.substring(start);
    if (missing.isNotEmpty) {
      _insertText(missing);
    }
    setState(() {
      _keyword = command;
      _selectedIndex = 0;
    });
    _maybeFetchLinkableModels();
  }

  void _maybeFetchLinkableModels() {
    final modelType = _selectedLinkableType;
    if (modelType == null) {
      setState(() {
        _loadingLinkableModels = false;
        _linkableResults = const <LinkedModel>[];
      });
      return;
    }
    final requestId = ++_linkableRequestId;
    final query = _keyword.substring(modelType.command.length + 1);
    setState(() {
      _loadingLinkableModels = true;
      _linkableResults = const <LinkedModel>[];
    });
    widget
        .searchLinkableModels(modelType: modelType, query: query)
        .then((models) {
          if (!mounted || requestId != _linkableRequestId) {
            return;
          }
          setState(() {
            _loadingLinkableModels = false;
            _linkableResults = models;
            _selectedIndex = 0;
          });
        })
        .catchError((Object _) {
          if (!mounted || requestId != _linkableRequestId) {
            return;
          }
          setState(() {
            _loadingLinkableModels = false;
            _linkableResults = const <LinkedModel>[];
          });
        });
  }

  void _selectStaticItem(SelectionMenuItem item) {
    item.handler(widget.editorState, widget.menuService, context);
  }

  void _selectLinkableModel(LinkableModelType modelType, LinkedModel model) {
    _deleteSlashKeywordAndInsertLinkableModel(modelType, model);
    widget.onLinkableModelSelected(modelType, model);
    widget.onDismiss();
  }

  Future<void> _createAndSelectEssay(String title) async {
    final model = await widget.createLinkedEssay(title);
    if (!mounted) return;
    _deleteSlashKeywordAndInsertLinkableModel(LinkableModelType.essay, model);
    await widget.onLinkableModelSelected(LinkableModelType.essay, model);
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

  void _deleteSlashKeywordAndInsertLinkableModel(
    LinkableModelType modelType,
    LinkedModel model,
  ) {
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
    final commandStart = end - _keyword.length - 1;
    if (commandStart < 0 ||
        commandStart >= plainText.length ||
        plainText[commandStart] != '/') {
      return;
    }
    final href = nxKgqlHrefForModel(modelType, model);
    final needsLeadingSpace =
        commandStart > 0 &&
        plainText.substring(0, commandStart).trimRight().length == commandStart;
    final needsTrailingSpace =
        end == plainText.length || plainText.substring(end).startsWith(' ');
    final transaction = widget.editorState.transaction;
    transaction.deleteText(node, commandStart, end - commandStart);
    var insertIndex = commandStart;
    if (needsLeadingSpace) {
      transaction.insertText(node, insertIndex, ' ', sliceAttributes: false);
      insertIndex += 1;
    }
    transaction.insertText(
      node,
      insertIndex,
      model.name,
      attributes: <String, dynamic>{BuiltInAttributeKey.href: href},
      sliceAttributes: false,
    );
    insertIndex += model.name.length;
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

class _NxLinkableModelCommandRow implements _NxSlashRow {
  const _NxLinkableModelCommandRow({
    required this.modelType,
    required this.onSelected,
  });

  final LinkableModelType modelType;
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
      icon: _iconForLinkableModelType(modelType),
      title: modelType.kgqlName,
      subtitle: 'Search ${modelType.kgqlName} models',
      onTap: onSelected,
    );
  }

  @override
  void select() => onSelected();
}

class _NxLinkableModelResultRow implements _NxSlashRow {
  const _NxLinkableModelResultRow({
    this.model,
    this.icon,
    this.title,
    this.subtitle,
    required this.onSelected,
  });

  final LinkedModel? model;
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final VoidCallback onSelected;

  @override
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  }) {
    final model = this.model;
    return _NxSlashTile(
      selected: selected,
      icon: icon ?? _iconForModelTypeName(model?.modelType ?? ''),
      title: title ?? model?.name ?? '',
      subtitle: subtitle ?? model?.modelType,
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
  });

  final bool selected;
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
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

IconData _iconForLinkableModelType(LinkableModelType modelType) {
  return _iconForModelTypeName(modelType.kgqlName);
}

IconData _iconForModelTypeName(String modelType) {
  return switch (modelType) {
    'Project' => Icons.folder_open_outlined,
    'Person' => Icons.person_outline,
    'Company' => Icons.business_outlined,
    'Essay' => Icons.article_outlined,
    _ => Icons.link,
  };
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
