part of 'document_editor_view.dart';

class _EditorFindBar extends StatefulWidget {
  const _EditorFindBar({
    required this.searchService,
    required this.onClose,
    super.key,
  });

  final SearchServiceV3 searchService;
  final VoidCallback onClose;

  @override
  State<_EditorFindBar> createState() => _EditorFindBarState();
}

class _EditorFindBarState extends State<_EditorFindBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleQueryChanged);
    _focusNode = FocusNode(debugLabel: 'nx_editor_find');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleQueryChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _error = widget.searchService.findAndHighlight(_controller.text);
    });
  }

  void _navigate({required bool previous}) {
    if (widget.searchService.matchWrappers.value.isEmpty) {
      return;
    }
    widget.searchService.navigateToMatch(moveUp: previous);
    Future.delayed(const Duration(milliseconds: 20), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _navigate(previous: HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _navigate(previous: false);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _navigate(previous: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(7),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1a000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 180,
                height: 30,
                child: Focus(
                  onKeyEvent: _handleKeyEvent,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: TextStyle(fontSize: 13, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Find in document',
                      hintStyle: TextStyle(color: AppColors.faint),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  widget.searchService.matchWrappers,
                  widget.searchService.currentSelectedIndex,
                ]),
                builder: (context, _) {
                  return SizedBox(
                    width: 54,
                    child: Text(
                      _countLabel(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  );
                },
              ),
              _FindIconButton(
                icon: Icons.keyboard_arrow_up,
                tooltip: 'Previous match',
                onPressed: () => _navigate(previous: true),
              ),
              _FindIconButton(
                icon: Icons.keyboard_arrow_down,
                tooltip: 'Next match',
                onPressed: () => _navigate(previous: false),
              ),
              _FindIconButton(
                icon: Icons.close,
                tooltip: 'Close find',
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _countLabel() {
    final query = _controller.text;
    if (query.isEmpty) {
      return '';
    }
    if (_error == 'Regex') {
      return 'Regex';
    }
    final count = widget.searchService.matchWrappers.value.length;
    if (count == 0) {
      return '0/0';
    }
    return '${widget.searchService.selectedIndex + 1}/$count';
  }
}

class _FindIconButton extends StatelessWidget {
  const _FindIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 18, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _ReadEditModeToggle extends StatefulWidget {
  const _ReadEditModeToggle({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final _DocumentEditorMode mode;
  final ValueChanged<_DocumentEditorMode> onChanged;

  @override
  State<_ReadEditModeToggle> createState() => _ReadEditModeToggleState();
}

class _ReadEditModeToggleState extends State<_ReadEditModeToggle> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel.withValues(alpha: 0.72),
      elevation: 1,
      shadowColor: const Color(0x1f000000),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ReadEditModeButton(
              icon: Icons.article_outlined,
              label: 'Read',
              selected: widget.mode == _DocumentEditorMode.read,
              onPressed: () => widget.onChanged(_DocumentEditorMode.read),
            ),
            const SizedBox(width: 2),
            _ReadEditModeButton(
              icon: Icons.keyboard_alt_outlined,
              label: 'Edit',
              selected: widget.mode == _DocumentEditorMode.edit,
              onPressed: () => widget.onChanged(_DocumentEditorMode.edit),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadEditModeButton extends StatelessWidget {
  const _ReadEditModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onFloating : AppColors.muted;
    return InkWell(
      onTap: selected ? null : onPressed,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? AppColors.floating : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: foreground),
      ),
    );
  }
}

enum _DocumentEditorMode {
  read,
  edit;

  bool get showsCaret => this == edit;

  String get storageValue {
    return switch (this) {
      _DocumentEditorMode.read => 'read',
      _DocumentEditorMode.edit => 'edit',
    };
  }
}

class _DocumentScrollAnchor {
  const _DocumentScrollAnchor({
    required this.documentId,
    required this.blockIndex,
    required this.blockKey,
    required this.alignment,
  });

  final int documentId;
  final int blockIndex;
  final String blockKey;
  final double alignment;

  Map<String, Object> toJson() {
    return <String, Object>{
      'version': 1,
      'documentId': documentId,
      'blockIndex': blockIndex,
      'blockKey': blockKey,
      'alignment': alignment,
    };
  }

  static _DocumentScrollAnchor? tryParse(Map<String, dynamic> json) {
    final documentId = _intFromJson(json['documentId']);
    final blockIndex = _intFromJson(json['blockIndex']);
    final blockKey = json['blockKey'];
    final alignment = _doubleFromJson(json['alignment']);
    if (documentId == null ||
        blockIndex == null ||
        blockKey is! String ||
        blockKey.isEmpty ||
        alignment == null) {
      return null;
    }
    return _DocumentScrollAnchor(
      documentId: documentId,
      blockIndex: blockIndex,
      blockKey: blockKey,
      alignment: alignment.clamp(-2.0, 2.0).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _DocumentScrollAnchor &&
        other.documentId == documentId &&
        other.blockIndex == blockIndex &&
        other.blockKey == blockKey &&
        other.alignment == alignment;
  }

  @override
  int get hashCode => Object.hash(documentId, blockIndex, blockKey, alignment);
}

_DocumentScrollAnchor? _scrollAnchorFromJsonDocument(
  Map<String, dynamic> jsonDocument,
) {
  final viewState = jsonDocument['view_state'];
  if (viewState is! Map) {
    return null;
  }
  final scrollAnchor = viewState['scroll_anchor'];
  if (scrollAnchor is! Map) {
    return null;
  }
  return _DocumentScrollAnchor.tryParse(
    Map<String, dynamic>.from(scrollAnchor),
  );
}

_DocumentEditorMode _editorModeFromJsonDocument(
  Map<String, dynamic> jsonDocument,
) {
  final viewState = jsonDocument['view_state'];
  if (viewState is! Map) {
    return _DocumentEditorMode.edit;
  }
  return switch (viewState['editor_mode']) {
    'read' => _DocumentEditorMode.read,
    'edit' => _DocumentEditorMode.edit,
    _ => _DocumentEditorMode.edit,
  };
}

Map<String, dynamic> _jsonDocumentViewState(
  Map<String, dynamic> jsonDocument, {
  required _DocumentEditorMode editorMode,
  _DocumentScrollAnchor? scrollAnchor,
}) {
  final existing = jsonDocument['view_state'];
  return <String, dynamic>{
    if (existing is Map) ...Map<String, dynamic>.from(existing),
    'editor_mode': editorMode.storageValue,
    if (scrollAnchor != null)
      'scroll_anchor': <String, dynamic>{
        ...scrollAnchor.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
  };
}

String _scrollAnchorBlockKey(Node node) {
  final text = _scrollAnchorNodeText(
    node,
  ).trim().replaceAll(RegExp(r'\s+'), ' ');
  return '${node.type}:${_stableHash('$text|${node.type}')}';
}

String _scrollAnchorNodeText(Node node) {
  final buffer = StringBuffer();

  void visit(Node current) {
    final text = current.delta?.toPlainText().isNotEmpty == true
        ? current.delta?.toPlainText()
        : nxPlainTextForCustomNode(current);
    if (text != null && text.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write(text);
    }
    for (final child in current.children) {
      visit(child);
    }
  }

  visit(node);
  return buffer.toString();
}

String _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

int? _intFromJson(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

double? _doubleFromJson(Object? value) {
  return switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };
}
