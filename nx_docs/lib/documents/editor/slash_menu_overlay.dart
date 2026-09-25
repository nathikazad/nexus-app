part of 'nx_appflowy_blocks.dart';

class NxSlashMenuOverlay extends StatefulWidget {
  const NxSlashMenuOverlay({
    required this.editorState,
    this.insertionSelection,
    required this.searchLinkableModels,
    required this.createLinkedDocument,
    required this.onLinkableModelSelected,
    this.uploadDocumentImage,
    required this.onDismiss,
    super.key,
  });

  final EditorState editorState;
  final Selection? insertionSelection;
  final Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels;
  final Future<LinkedModel> Function(String title) createLinkedDocument;
  final Future<void> Function(LinkableModelType modelType, LinkedModel model)
  onLinkableModelSelected;
  final Future<String> Function(String source)? uploadDocumentImage;
  final VoidCallback onDismiss;

  @override
  State<NxSlashMenuOverlay> createState() => _NxSlashMenuOverlayState();
}

class _NxSlashMenuOverlayState extends State<NxSlashMenuOverlay> {
  final _focusNode = FocusNode(debugLabel: 'nx_slash_menu');
  late final List<SelectionMenuItem> _staticItems;
  late final SelectionMenuService _menuService;
  final _searchController = TextEditingController();
  var _keyword = '';
  var _selectedIndex = 0;
  var _loadingLinkableModels = false;
  var _linkableRequestId = 0;
  List<LinkedModel> _linkableResults = const <LinkedModel>[];

  @override
  void initState() {
    super.initState();
    // Preserve the insertion point while the menu owns keyboard focus, just
    // like AppFlowy's built-in selection menu.
    keepEditorFocusNotifier.increase();
    _menuService = _NxSelectionMenuService(
      onDismiss: widget.onDismiss,
      style: AppColors.isDark
          ? SelectionMenuStyle.dark
          : SelectionMenuStyle.light,
    );
    _staticItems = _nxStaticSelectionMenuItems(
      uploadDocumentImage: widget.uploadDocumentImage,
    );
    for (final item in _staticItems) {
      item.onSelected = widget.onDismiss;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !usesTouchEditingControls(context)) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    keepEditorFocusNotifier.decrease();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (usesTouchEditingControls(context)) {
      return Material(
        color: AppColors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Insert block',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close insert',
                      onPressed: widget.onDismiss,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.subtle,
                        foregroundColor: AppColors.muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search blocks or links',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    filled: true,
                    fillColor: AppColors.subtle,
                    hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.blue),
                    ),
                  ),
                  onChanged: _searchFromKeyboard,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loadingLinkableModels
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                    ? const Center(child: Text('No results'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: rows.length,
                        itemBuilder: (context, index) => ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: rows[index].build(
                            context,
                            selected: false,
                            editorState: widget.editorState,
                            style: _menuService.style,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.panel,
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
                        style: _menuService.style,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  void _searchFromKeyboard(String value) {
    final selection = _restoreInsertionSelection();
    if (selection == null) return;
    final node = widget.editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;
    final start = selection.end.offset - _keyword.length;
    if (start < 0) return;
    final transaction = widget.editorState.transaction
      ..deleteText(node, start, _keyword.length)
      ..insertText(node, start, value)
      ..afterSelection = Selection.collapsed(
        Position(path: selection.end.path, offset: start + value.length),
      );
    widget.editorState.apply(transaction);
    setState(() {
      _keyword = value;
      _selectedIndex = 0;
    });
    _maybeFetchLinkableModels();
  }

  List<_NxSlashRow> get _rows {
    final selectedType = _selectedLinkableType;
    if (selectedType != null) {
      return <_NxSlashRow>[
        if (selectedType == LinkableModelType.document)
          _NxLinkableModelResultRow(
            icon: Icons.add,
            title: 'Create "$_linkableQueryTitle"',
            subtitle: 'New document',
            onSelected: () => _createAndSelectDocument(_linkableQueryTitle),
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
      for (final item in _staticItems)
        if (lowerKeyword.isEmpty ||
            item.allKeywords.any((keyword) => keyword.contains(lowerKeyword)))
          _NxSelectionItemRow(
            item: item,
            onSelected: () => _selectStaticItem(item),
          ),
      for (final type in LinkableModelType.values)
        if (lowerKeyword.isEmpty ||
            type.command.contains(lowerKeyword) ||
            type.kgqlName.toLowerCase().contains(lowerKeyword))
          _NxLinkableModelCommandRow(
            modelType: type,
            onSelected: () => _enterLinkableModelSearch(type),
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
    return query.isEmpty ? 'Untitled document' : query;
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
    _searchController.text = _keyword;
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

  Selection? _restoreInsertionSelection() {
    final current = widget.editorState.selection;
    if (current != null) return current;
    final initial = widget.insertionSelection;
    if (initial == null || widget.editorState.isDisposed) return null;
    final selection = Selection.collapsed(
      Position(
        path: initial.start.path,
        offset: initial.start.offset + _keyword.length,
      ),
    );
    widget.editorState.selection = selection;
    return selection;
  }

  void _selectStaticItem(SelectionMenuItem item) {
    _restoreInsertionSelection();
    item.handler(widget.editorState, _menuService, context);
  }

  void _selectLinkableModel(LinkableModelType modelType, LinkedModel model) {
    _deleteSlashKeywordAndInsertLinkableModel(modelType, model);
    widget.onLinkableModelSelected(modelType, model);
    widget.onDismiss();
  }

  Future<void> _createAndSelectDocument(String title) async {
    final model = await widget.createLinkedDocument(title);
    if (!mounted) return;
    _deleteSlashKeywordAndInsertLinkableModel(
      LinkableModelType.document,
      model,
    );
    await widget.onLinkableModelSelected(LinkableModelType.document, model);
    widget.onDismiss();
  }

  void _insertText(String text) {
    final selection = _restoreInsertionSelection();
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
    final selection = _restoreInsertionSelection();
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
    final selection = _restoreInsertionSelection();
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
