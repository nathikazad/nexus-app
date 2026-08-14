part of 'document_editor_view.dart';

class _NxAppFlowyEditor extends StatefulWidget {
  const _NxAppFlowyEditor({
    required this.document,
    required this.changeOrigin,
    required this.textScaleFactor,
    required this.editorMode,
    required this.readOnly,
    required this.onFindBarChanged,
    required this.searchLinkableModels,
    this.onChanged,
    this.onLinkableModelSelected,
    this.createLinkedDocument,
    this.uploadDocumentImage,
    this.deleteDocumentImage,
    this.resolveDocumentImage,
    this.documentImageBaseUrl,
    this.active = true,
  });

  final NxDocument document;
  final DocumentChangeOrigin changeOrigin;
  final double textScaleFactor;
  final _DocumentEditorMode editorMode;
  final bool readOnly;
  final bool active;
  final Future<void> Function(NxDocument document, DraftSavePolicy policy)?
  onChanged;
  final ValueChanged<_EditorFindBarPresentation?> onFindBarChanged;
  final Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels;
  final Future<void> Function(LinkableModelType modelType, LinkedModel model)?
  onLinkableModelSelected;
  final Future<LinkedModel> Function(String title)? createLinkedDocument;
  final Future<String> Function(String source)? uploadDocumentImage;
  final Future<void> Function(String url)? deleteDocumentImage;
  final String Function(String url)? resolveDocumentImage;
  final String? documentImageBaseUrl;

  @override
  State<_NxAppFlowyEditor> createState() => _NxAppFlowyEditorState();
}

class _EditorFindBarPresentation {
  const _EditorFindBarPresentation({
    required this.searchService,
    required this.onClose,
    required this.serial,
  });

  final SearchServiceV3 searchService;
  final VoidCallback onClose;
  final int serial;
}

bool _isRemoteOrigin(DocumentChangeOrigin origin) {
  return origin == DocumentChangeOrigin.initialRemoteLoad ||
      origin == DocumentChangeOrigin.remoteRefresh ||
      origin == DocumentChangeOrigin.snapshotRestore;
}

String _contentFingerprint(NxDocument document) {
  final appFlowyDocument = document.jsonDocument['document'];
  return appFlowyDocument == null
      ? document.document
      : jsonEncode(appFlowyDocument);
}

class _NxAppFlowyEditorState extends State<_NxAppFlowyEditor> {
  static const _scrollAnchorSaveDelay = Duration(milliseconds: 450);
  static const _scrollAnchorRestoreRetryDelay = Duration(milliseconds: 80);
  static const _maxScrollAnchorRestoreAttempts = 16;
  static const _pasteShortcutKeys = <String>{
    'paste the content',
    'paste the content as plain text',
  };

  late EditorState _editorState;
  late EditorScrollController _scrollController;
  StreamSubscription<EditorTransactionValue>? _transactionSubscription;
  Timer? _saveDebounce;
  Timer? _nextImmediateSaveTimer;
  Timer? _scrollAnchorSaveDebounce;
  SearchServiceV3? _findSearchService;
  bool _activeHeadingPublishScheduled = false;
  bool _scrollAnchorSaveEnabled = false;
  bool _skipNextScrollAnchorSave = true;
  bool _saveNextTransactionImmediately = false;
  bool _showFindBar = false;
  late NxDocument _editorDocument;
  late int _editorDocumentId;
  int? _handledHeadingScrollRequestSerial;
  int _handledFindRequestSerial = 0;
  int _findBarOpenSerial = 0;
  int _scrollAnchorRestoreAttempts = 0;
  double _documentScrollProgress = 0;
  bool _documentCanScroll = false;
  _DocumentScrollAnchor? _lastSavedScrollAnchor;

  @override
  void initState() {
    super.initState();
    _createEditor();
  }

  @override
  void didUpdateWidget(covariant _NxAppFlowyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _disposeEditor();
      _createEditor();
      return;
    }
    if (_isRemoteOrigin(widget.changeOrigin) &&
        _contentFingerprint(oldWidget.document) !=
            _contentFingerprint(widget.document)) {
      unawaited(_applyExternalDocument(widget.document));
    }
    if (oldWidget.editorMode != widget.editorMode ||
        oldWidget.readOnly != widget.readOnly) {
      _handleEditorModeChanged();
    }
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _scheduleActiveHeadingPublish();
      } else {
        _clearActiveHeading();
        _closeFindBar();
      }
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _nextImmediateSaveTimer?.cancel();
    _clearActiveHeading(afterFrame: true);
    _disposeEditor();
    super.dispose();
  }

  void _createEditor() {
    registerNxHighlightNoteAttribute();
    _editorDocument = widget.document;
    _editorDocumentId = widget.document.id;
    _lastSavedScrollAnchor = null;
    _scrollAnchorSaveEnabled = false;
    _skipNextScrollAnchorSave = true;
    _showFindBar = false;
    _editorState = EditorState(
      document: _documentFromDocument(widget.document),
    );
    _editorState.editable = !widget.readOnly;
    _scrollController = EditorScrollController(
      editorState: _editorState,
      shrinkWrap: false,
    );
    _findSearchService = SearchServiceV3(editorState: _editorState);
    _scrollController.itemPositionsListener.itemPositions.addListener(
      _handleVisibleItemPositionsChanged,
    );
    _scrollController.offsetNotifier.addListener(_handleEditorScrolled);
    documentHeadingScrollRequestNotifier.addListener(
      _handleHeadingScrollRequest,
    );
    editorFindRequestNotifier.addListener(_handleFindRequest);
    documentAudioBlockRequestNotifier.addListener(_handleAudioBlockRequest);
    _transactionSubscription = _editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      if (time == TransactionTime.after &&
          !options.inMemoryUpdate &&
          transaction.operations.isNotEmpty) {
        _scheduleSave(_savePolicyForTransaction(transaction));
        _scheduleActiveHeadingPublish();
      }
    });
    _scheduleActiveHeadingPublish();
    _restoreScrollAnchor();
  }

  void _disposeEditor() {
    _nextImmediateSaveTimer?.cancel();
    _nextImmediateSaveTimer = null;
    _scrollAnchorSaveDebounce?.cancel();
    _scrollAnchorSaveDebounce = null;
    _scrollAnchorSaveEnabled = false;
    _saveNextTransactionImmediately = false;
    _scrollController.itemPositionsListener.itemPositions.removeListener(
      _handleVisibleItemPositionsChanged,
    );
    _scrollController.offsetNotifier.removeListener(_handleEditorScrolled);
    documentHeadingScrollRequestNotifier.removeListener(
      _handleHeadingScrollRequest,
    );
    editorFindRequestNotifier.removeListener(_handleFindRequest);
    documentAudioBlockRequestNotifier.removeListener(_handleAudioBlockRequest);
    widget.onFindBarChanged(null);
    _transactionSubscription?.cancel();
    _findSearchService?.findAndHighlight('');
    _findSearchService?.dispose();
    _findSearchService = null;
    _scrollController.dispose();
    _editorState.dispose();
  }

  Document _documentFromDocument(NxDocument document) {
    if (document.jsonDocument['format'] == 'appflowy_document') {
      final documentJson = document.jsonDocument['document'];
      if (documentJson is Map) {
        return Document.fromJson(<String, dynamic>{
          'document': Map<String, dynamic>.from(documentJson),
        });
      }
    }

    if (document.document.trim().isNotEmpty) {
      return markdownToDocument(document.document);
    }

    return Document.blank(withInitialText: true);
  }

  Future<void> _applyExternalDocument(NxDocument document) async {
    _scrollAnchorSaveDebounce?.cancel();
    _skipNextScrollAnchorSave = true;
    final incoming = _documentFromDocument(document);
    final transaction = _editorState.transaction;
    final existingCount = _editorState.document.root.children.length;
    if (existingCount > 0) {
      transaction.deleteNodesAtPath(<int>[0], existingCount);
    }
    transaction.insertNodes(<int>[0], incoming.root.children);
    final wasEditable = _editorState.editable;
    _editorState.editable = true;
    try {
      await _editorState.apply(
        transaction,
        options: const ApplyOptions(recordUndo: false, inMemoryUpdate: true),
        withUpdateSelection: false,
      );
      _editorDocument = document;
    } finally {
      _editorState.editable = wasEditable;
    }
  }

  void _handleEditorScrolled() {
    _scheduleScrollAnchorSave();
  }

  void _handleVisibleItemPositionsChanged() {
    _scheduleActiveHeadingPublish();
    _scheduleScrollAnchorSave();
    _updateDocumentScrollProgress();
  }

  void _updateDocumentScrollProgress() {
    if (!mounted) return;
    final childCount = _editorState.document.root.children.length;
    final visible =
        _scrollController.itemPositionsListener.itemPositions.value
            .where(
              (position) =>
                  position.index >= 0 &&
                  position.index < childCount &&
                  position.itemTrailingEdge > 0 &&
                  position.itemLeadingEdge < 1,
            )
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    if (childCount < 2 || visible.isEmpty) return;

    final first = visible.first;
    final last = visible.last;
    final canScroll =
        visible.length < childCount ||
        first.itemLeadingEdge < -0.01 ||
        last.itemTrailingEdge > 1.01;
    final double progress;
    if (first.index == 0 && first.itemLeadingEdge >= -0.01) {
      progress = 0;
    } else if (last.index == childCount - 1 && last.itemTrailingEdge <= 1.01) {
      progress = 1;
    } else {
      final center = visible.reduce((closest, candidate) {
        final closestDistance =
            ((closest.itemLeadingEdge + closest.itemTrailingEdge) / 2 - 0.5)
                .abs();
        final candidateDistance =
            ((candidate.itemLeadingEdge + candidate.itemTrailingEdge) / 2 - 0.5)
                .abs();
        return candidateDistance < closestDistance ? candidate : closest;
      });
      progress = center.index / (childCount - 1);
    }
    if (canScroll == _documentCanScroll &&
        (progress - _documentScrollProgress).abs() < 0.005) {
      return;
    }
    setState(() {
      _documentCanScroll = canScroll;
      _documentScrollProgress = progress.clamp(0, 1).toDouble();
    });
  }

  void _handleAudioBlockRequest() {
    final request = documentAudioBlockRequestNotifier.value;
    if (request == null || request.documentId != _editorDocumentId) return;
    final children = _editorState.document.root.children;
    var index = -1;
    for (var candidate = 0; candidate < children.length; candidate++) {
      if (_scrollAnchorBlockKey(children[candidate]) == request.blockKey) {
        index = candidate;
        break;
      }
    }
    if (index < 0 &&
        request.blockIndex >= 0 &&
        request.blockIndex < children.length) {
      index = request.blockIndex;
    }
    if (index < 0 || !_scrollController.itemScrollController.isAttached) {
      return;
    }
    _scrollController.itemScrollController.scrollTo(
      index: index,
      alignment: 0.18,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _scheduleSave(DraftSavePolicy policy) {
    _saveDebounce?.cancel();
    if (policy == DraftSavePolicy.immediate) {
      _saveCurrentDraft(policy);
      return;
    }
    _saveDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _saveCurrentDraft(policy),
    );
  }

  void _saveCurrentDraft(DraftSavePolicy policy) {
    final onChanged = widget.onChanged;
    if (widget.readOnly || onChanged == null) return;
    unawaited(onChanged(_currentDraftDocument(), policy));
  }

  NxDocument _currentDraftDocument({_DocumentScrollAnchor? scrollAnchor}) {
    final plainText = _documentPlainText(_editorState.document).trimRight();
    final baseDocument = widget.document.id == _editorDocumentId
        ? widget.document
        : _editorDocument;
    final nextScrollAnchor =
        scrollAnchor ??
        _lastSavedScrollAnchor ??
        _scrollAnchorFromJsonDocument(baseDocument.jsonDocument);
    final jsonDocument = <String, dynamic>{
      ...baseDocument.jsonDocument,
      'format': 'appflowy_document',
      'document': _editorState.document.toJson()['document'],
      'view_state': _jsonDocumentViewState(
        baseDocument.jsonDocument,
        editorMode: widget.editorMode,
        scrollAnchor: nextScrollAnchor,
      ),
    };
    return baseDocument.copyWith(
      document: plainText,
      jsonDocument: jsonDocument,
      wordCount: _countWords(plainText),
      excerpt: _excerptFrom(plainText),
    );
  }

  DraftSavePolicy _savePolicyForTransaction(Transaction transaction) {
    if (_consumeImmediateSaveMarker()) {
      return DraftSavePolicy.immediate;
    }
    return _transactionLooksLikeTyping(transaction)
        ? DraftSavePolicy.deferred
        : DraftSavePolicy.immediate;
  }

  bool _transactionLooksLikeTyping(Transaction transaction) {
    return transaction.operations.every(_operationLooksLikeTyping);
  }

  bool _operationLooksLikeTyping(Operation operation) {
    if (operation is! UpdateTextOperation) {
      return false;
    }

    var changedText = false;
    for (final deltaOperation in operation.delta) {
      if (deltaOperation is TextRetain) {
        if (deltaOperation.attributes?.isNotEmpty ?? false) {
          return false;
        }
      } else if (deltaOperation is TextInsert) {
        final attributes = deltaOperation.attributes;
        if ((attributes?[BuiltInAttributeKey.href] != null) ||
            (attributes?[nxHighlightNoteIdAttribute] != null) ||
            deltaOperation.text.length > 1) {
          return false;
        }
        changedText = true;
      } else if (deltaOperation is TextDelete) {
        if (deltaOperation.length > 1) {
          return false;
        }
        changedText = true;
      }
    }
    return changedText;
  }

  void _markNextTransactionForImmediateSave() {
    _saveNextTransactionImmediately = true;
    _nextImmediateSaveTimer?.cancel();
    _nextImmediateSaveTimer = Timer(const Duration(seconds: 5), () {
      _saveNextTransactionImmediately = false;
      _nextImmediateSaveTimer = null;
    });
  }

  bool _consumeImmediateSaveMarker() {
    if (!_saveNextTransactionImmediately) {
      return false;
    }
    _saveNextTransactionImmediately = false;
    _nextImmediateSaveTimer?.cancel();
    _nextImmediateSaveTimer = null;
    return true;
  }

  List<CommandShortcutEvent> _commandShortcutEvents() {
    final findInDocument = CommandShortcutEvent(
      key: 'nx open editor find',
      getDescription: () => 'Find in document',
      command: 'ctrl+f',
      macOSCommand: 'cmd+f',
      handler: (editorState) {
        _openFindBar();
        return KeyEventResult.handled;
      },
    );
    if (widget.readOnly) {
      return <CommandShortcutEvent>[findInDocument];
    }
    return <CommandShortcutEvent>[
      findInDocument,
      for (final event in standardCommandShortcutEvents)
        if (_pasteShortcutKeys.contains(event.key))
          event.copyWith(
            handler: (editorState) {
              _markNextTransactionForImmediateSave();
              final result = event.handler(editorState);
              if (result == KeyEventResult.ignored) {
                _consumeImmediateSaveMarker();
              }
              return result;
            },
          )
        else
          event,
    ];
  }

  String _documentPlainText(Document document) {
    final buffer = StringBuffer();
    void visit(Node node) {
      final text = node.delta?.toPlainText().isNotEmpty == true
          ? node.delta?.toPlainText()
          : nxPlainTextForCustomNode(node);
      if (text != null && text.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.write(text);
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final child in document.root.children) {
      visit(child);
    }
    return buffer.toString();
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return RegExp(r'\S+').allMatches(trimmed).length;
  }

  String _excerptFrom(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 140) {
      return normalized;
    }
    return '${normalized.substring(0, 137)}...';
  }

  void _scheduleActiveHeadingPublish() {
    if (!widget.active) return;
    if (_activeHeadingPublishScheduled) return;
    _activeHeadingPublishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activeHeadingPublishScheduled = false;
      _publishActiveHeading();
    });
  }

  void _restoreScrollAnchor() {
    final documentId = _editorDocumentId;
    _scrollAnchorSaveEnabled = false;
    _scrollAnchorRestoreAttempts = 0;
    final anchor = _scrollAnchorFromJsonDocument(widget.document.jsonDocument);
    if (!mounted || _editorDocumentId != documentId) {
      return;
    }
    if (anchor == null || anchor.documentId != documentId) {
      _scrollAnchorSaveEnabled = true;
      return;
    }
    _lastSavedScrollAnchor = anchor;
    _attemptScrollAnchorRestore(anchor);
  }

  void _attemptScrollAnchorRestore(_DocumentScrollAnchor anchor) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _editorDocumentId != anchor.documentId) {
        return;
      }
      final itemScrollController = _scrollController.itemScrollController;
      if (!itemScrollController.isAttached) {
        if (_scrollAnchorRestoreAttempts < _maxScrollAnchorRestoreAttempts) {
          _scrollAnchorRestoreAttempts += 1;
          Timer(
            _scrollAnchorRestoreRetryDelay,
            () => _attemptScrollAnchorRestore(anchor),
          );
        } else {
          _scrollAnchorSaveEnabled = true;
        }
        return;
      }

      final blockIndex = _resolveScrollAnchorBlockIndex(anchor);
      if (blockIndex != null) {
        itemScrollController.jumpTo(
          index: blockIndex,
          alignment: anchor.alignment,
        );
        _scheduleActiveHeadingPublish();
      }
      _scrollAnchorSaveEnabled = true;
    });
  }

  void _scheduleScrollAnchorSave() {
    if (!_scrollAnchorSaveEnabled || !widget.active) {
      return;
    }
    _scrollAnchorSaveDebounce?.cancel();
    _scrollAnchorSaveDebounce = Timer(
      _scrollAnchorSaveDelay,
      () => unawaited(_saveScrollAnchorNow()),
    );
  }

  Future<void> _saveScrollAnchorNow() async {
    final onChanged = widget.onChanged;
    if (!mounted ||
        !widget.active ||
        widget.readOnly ||
        onChanged == null ||
        !_scrollAnchorSaveEnabled) {
      return;
    }
    final anchor = _currentScrollAnchor();
    if (anchor == null) {
      return;
    }
    if (_skipNextScrollAnchorSave) {
      _skipNextScrollAnchorSave = false;
      _lastSavedScrollAnchor = anchor;
      return;
    }
    if (anchor == _lastSavedScrollAnchor) {
      return;
    }
    _lastSavedScrollAnchor = anchor;
    await onChanged(
      _currentDraftDocument(scrollAnchor: anchor),
      DraftSavePolicy.deferred,
    );
  }

  void _handleEditorModeChanged() {
    _editorState.editable = !widget.readOnly;
    final onChanged = widget.onChanged;
    if (widget.readOnly || onChanged == null) return;
    final anchor = _currentScrollAnchor();
    if (anchor != null) {
      _lastSavedScrollAnchor = anchor;
    }
    unawaited(
      onChanged(
        _currentDraftDocument(scrollAnchor: anchor),
        DraftSavePolicy.immediate,
      ),
    );
  }

  _DocumentScrollAnchor? _currentScrollAnchor() {
    final children = _editorState.document.root.children;
    if (children.isEmpty) {
      return null;
    }
    final visible = _scrollController.itemPositionsListener.itemPositions.value
        .where(
          (position) =>
              position.index >= 0 &&
              position.index < children.length &&
              position.itemTrailingEdge > 0 &&
              position.itemLeadingEdge < 1,
        )
        .toList();
    if (visible.isEmpty) {
      return null;
    }

    double distanceToCenter(dynamic position) {
      final center = (position.itemLeadingEdge + position.itemTrailingEdge) / 2;
      return (center - 0.5).abs();
    }

    visible.sort((a, b) => distanceToCenter(a).compareTo(distanceToCenter(b)));
    final position = visible.first;
    final block = children[position.index];
    return _DocumentScrollAnchor(
      documentId: _editorDocumentId,
      blockIndex: position.index,
      blockKey: _scrollAnchorBlockKey(block),
      alignment: position.itemLeadingEdge.clamp(-2.0, 2.0).toDouble(),
    );
  }

  int? _resolveScrollAnchorBlockIndex(_DocumentScrollAnchor anchor) {
    final children = _editorState.document.root.children;
    final matchingIndexes = <int>[];
    for (var i = 0; i < children.length; i++) {
      if (_scrollAnchorBlockKey(children[i]) == anchor.blockKey) {
        matchingIndexes.add(i);
      }
    }
    if (matchingIndexes.isNotEmpty) {
      matchingIndexes.sort(
        (a, b) => (a - anchor.blockIndex).abs().compareTo(
          (b - anchor.blockIndex).abs(),
        ),
      );
      return matchingIndexes.first;
    }
    if (anchor.blockIndex >= 0 && anchor.blockIndex < children.length) {
      return anchor.blockIndex;
    }
    if (children.isEmpty) {
      return null;
    }
    return children.length - 1;
  }

  void _handleHeadingScrollRequest() {
    final request = documentHeadingScrollRequestNotifier.value;
    if (!mounted ||
        !widget.active ||
        request == null ||
        request.documentId != widget.document.id ||
        request.serial == _handledHeadingScrollRequestSerial) {
      return;
    }
    _handledHeadingScrollRequestSerial = request.serial;

    final blockIndex = request.blockIndex;
    if (blockIndex < 0 ||
        blockIndex >= _editorState.document.root.children.length) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      final itemScrollController = _scrollController.itemScrollController;
      if (!itemScrollController.isAttached) return;
      itemScrollController.jumpTo(index: blockIndex, alignment: 0.08);
      _scheduleActiveHeadingPublish();
    });
  }

  void _handleFindRequest() {
    final request = editorFindRequestNotifier.value;
    if (!mounted ||
        !widget.active ||
        request.documentId != widget.document.id ||
        request.serial == _handledFindRequestSerial) {
      return;
    }
    _handledFindRequestSerial = request.serial;
    _openFindBar();
  }

  void _openFindBar() {
    if (!mounted || !widget.active || _findSearchService == null) {
      return;
    }
    setState(() {
      _showFindBar = true;
      _findBarOpenSerial += 1;
    });
    widget.onFindBarChanged(
      _EditorFindBarPresentation(
        searchService: _findSearchService!,
        onClose: _closeFindBar,
        serial: _findBarOpenSerial,
      ),
    );
  }

  void _closeFindBar() {
    _findSearchService?.findAndHighlight('');
    widget.onFindBarChanged(null);
    if (!mounted || !_showFindBar) return;
    setState(() => _showFindBar = false);
  }

  void _publishActiveHeading() {
    if (!mounted || !widget.active) return;
    final children = _editorState.document.root.children;
    final headingIndexes = <int>[
      for (var i = 0; i < children.length; i++)
        if (children[i].type == 'heading' &&
            (children[i].delta?.toPlainText().trim().isNotEmpty ?? false))
          i,
    ];
    if (headingIndexes.isEmpty) {
      _setActiveHeading(null);
      return;
    }

    final visible = _scrollController.itemPositionsListener.itemPositions.value
        .where(
          (position) =>
              position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1,
        )
        .toList();
    if (visible.isEmpty) return;

    double distanceToCenter(dynamic position) {
      final center = (position.itemLeadingEdge + position.itemTrailingEdge) / 2;
      return (center - 0.5).abs();
    }

    final visibleHeadingPositions = visible
        .where((position) => headingIndexes.contains(position.index))
        .toList();
    if (visibleHeadingPositions.isNotEmpty) {
      visibleHeadingPositions.sort(
        (a, b) => distanceToCenter(a).compareTo(distanceToCenter(b)),
      );
      _setActiveHeading(visibleHeadingPositions.first.index);
      return;
    }

    visible.sort((a, b) => distanceToCenter(a).compareTo(distanceToCenter(b)));
    final centerBlockIndex = visible.first.index;
    final previousHeadings = headingIndexes
        .where((index) => index <= centerBlockIndex)
        .toList();
    _setActiveHeading(
      previousHeadings.isEmpty ? headingIndexes.first : previousHeadings.last,
    );
  }

  void _setActiveHeading(int? blockIndex) {
    if (!widget.active) return;
    final current = documentActiveHeadingNotifier.value;
    if (blockIndex == null) {
      if (current?.documentId == widget.document.id) {
        documentActiveHeadingNotifier.value = null;
      }
      return;
    }
    if (current?.documentId == widget.document.id &&
        current?.blockIndex == blockIndex) {
      return;
    }
    documentActiveHeadingNotifier.value = DocumentActiveHeading(
      documentId: widget.document.id,
      blockIndex: blockIndex,
    );
  }

  void _clearActiveHeading({bool afterFrame = false}) {
    final current = documentActiveHeadingNotifier.value;
    if (current?.documentId != widget.document.id) return;
    if (!afterFrame) {
      documentActiveHeadingNotifier.value = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(documentActiveHeadingNotifier.value, current)) {
        documentActiveHeadingNotifier.value = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showsCaret = widget.editorMode.showsCaret;
    final disableReaderKeyboard = widget.readOnly && !isDesktopLayout(context);
    final editorStyle = _editorStyle(
      widget.editorMode,
      textScaleFactor: widget.textScaleFactor,
    ).copyWith(cursorColor: showsCaret ? AppColors.text : Colors.transparent);
    final editor = AppFlowyEditor(
      editable: !widget.readOnly,
      disableKeyboardService: disableReaderKeyboard,
      editorState: _editorState,
      editorScrollController: _scrollController,
      editorStyle: editorStyle,
      blockComponentBuilders: nxBlockComponentBuilders(
        // AppFlowy's editable table can reserve its stored height without
        // painting imported cells on macOS. Keep the stable content renderer
        // in both modes so switching to Edit cannot reintroduce a blank block.
        useReadTable: true,
        deleteDocumentImage: widget.deleteDocumentImage,
        resolveDocumentImage: widget.resolveDocumentImage,
        documentImageBaseUrl: widget.documentImageBaseUrl,
      ),
      characterShortcutEvents: widget.readOnly
          ? const <CharacterShortcutEvent>[]
          : <CharacterShortcutEvent>[
              ...standardCharacterShortcutEvents.where(
                (event) => event.key != 'show the slash menu',
              ),
              nxSlashCommand(
                searchLinkableModels: widget.searchLinkableModels,
                createLinkedDocument: widget.createLinkedDocument!,
                onLinkableModelSelected: widget.onLinkableModelSelected!,
                uploadDocumentImage: widget.uploadDocumentImage,
              ),
            ],
      commandShortcutEvents: _commandShortcutEvents(),
      footer: SizedBox(height: widget.readOnly ? 24 : 120),
    );
    final Widget editorSurface;
    if (widget.readOnly) {
      editorSurface = editor;
    } else {
      editorSurface = FloatingToolbar(
        editorState: _editorState,
        editorScrollController: _scrollController,
        textDirection: Directionality.of(context),
        items: [
          paragraphItem,
          ...headingItems,
          ...markdownFormatItems,
          quoteItem,
          bulletedListItem,
          numberedListItem,
          linkItem,
          buildNxTextColorItem(),
          buildNxHighlightColorItem(),
          nxHighlightNoteToolbarItem,
          buildNxDocumentLinkToolbarItem(
            searchLinkableModels: widget.searchLinkableModels,
            createDocument: widget.createLinkedDocument!,
            onLinkableModelSelected: widget.onLinkableModelSelected!,
          ),
          ...alignmentItems,
        ],
        tooltipBuilder: (context, _, message, child) {
          return Tooltip(message: message, preferBelow: false, child: child);
        },
        child: editor,
      );
    }
    if (isDesktopLayout(context) || !_documentCanScroll) {
      return editorSurface;
    }
    return Stack(
      children: [
        Positioned.fill(child: editorSurface),
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
              child: Align(
                alignment: Alignment(1, _documentScrollProgress * 2 - 1),
                child: Container(
                  key: const ValueKey<String>('document-scroll-position-dot'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.text.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
