import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_result_context.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/features/document/document_actions.dart';
import 'package:nx_notes/features/editor/nx_appflowy_blocks.dart';
import 'package:nx_notes/features/editor/nx_color_toolbar.dart';
import 'package:nx_notes/features/editor/nx_document_link.dart';
import 'package:nx_notes/features/editor/nx_highlight_notes.dart';

class DocumentEditorView extends ConsumerWidget {
  const DocumentEditorView({
    required this.documentId,
    this.contextBar,
    this.onTitleChanged,
    this.onOpenDocumentLink,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.horizontalPadding = 48,
    this.active = true,
    super.key,
  });

  final int documentId;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<int>? onOpenDocumentLink;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final double horizontalPadding;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDocument = ref.watch(documentByIdProvider(documentId));
    return asyncDocument.when(
      data: (document) {
        if (document == null) {
          return const Center(child: Text('Document not found'));
        }
        return DocumentEditorBody(
          document: document,
          contextBar: contextBar,
          onTitleChanged: onTitleChanged,
          onOpenDocumentLink: onOpenDocumentLink,
          canNavigateBack: canNavigateBack,
          onNavigateBack: onNavigateBack,
          horizontalPadding: horizontalPadding,
          active: active,
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class DocumentEditorBody extends ConsumerStatefulWidget {
  const DocumentEditorBody({
    required this.document,
    this.contextBar,
    this.onTitleChanged,
    this.onOpenDocumentLink,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.horizontalPadding = 48,
    this.active = true,
    super.key,
  });

  final NxDocument document;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<int>? onOpenDocumentLink;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final double horizontalPadding;
  final bool active;

  @override
  ConsumerState<DocumentEditorBody> createState() => _DocumentEditorBodyState();
}

typedef _LaunchUrlHandler = Future<bool> Function(String? href);

class EditorFindRequest {
  const EditorFindRequest({required this.documentId, required this.serial});

  final int documentId;
  final int serial;
}

final editorFindRequestNotifier = ValueNotifier<EditorFindRequest>(
  const EditorFindRequest(documentId: -1, serial: 0),
);

class _DocumentLinkLaunchDispatcher {
  static final Map<Object, _LaunchUrlHandler> _handlers =
      <Object, _LaunchUrlHandler>{};
  static Object? _activeOwner;
  static _LaunchUrlHandler? _fallback;
  static var _installed = false;

  static void activate(Object owner, _LaunchUrlHandler handler) {
    _ensureInstalled();
    _handlers[owner] = handler;
    _activeOwner = owner;
  }

  static void deactivate(Object owner) {
    _handlers.remove(owner);
    if (_activeOwner == owner) {
      _activeOwner = null;
    }
  }

  static void _ensureInstalled() {
    if (_installed) return;
    _fallback = editorLaunchUrl;
    editorLaunchUrl = (href) async {
      final handler = _handlers[_activeOwner];
      if (handler != null && await handler(href)) {
        return true;
      }
      return _fallback!(href);
    };
    _installed = true;
  }
}

class _DocumentEditorBodyState extends ConsumerState<DocumentEditorBody> {
  Timer? _titleSaveDebounce;
  late NxDocument _draftDocument;
  late String _titleText;
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  bool _editingTitle = false;
  late _DocumentEditorMode _editorMode;
  _EditorFindBarPresentation? _findBarPresentation;
  final Object _linkHandlerOwner = Object();

  @override
  void initState() {
    super.initState();
    _draftDocument = widget.document;
    _titleText = widget.document.title;
    _editorMode = _editorModeFromJsonDocument(widget.document.jsonDocument);
    _titleController = TextEditingController(text: _titleText);
    _titleFocusNode = FocusNode()..addListener(_handleTitleFocusChange);
    _syncDocumentLinkHandler();
  }

  @override
  void didUpdateWidget(covariant DocumentEditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _titleSaveDebounce?.cancel();
      _draftDocument = widget.document;
      _replaceTitleText(widget.document.title);
      _editorMode = _editorModeFromJsonDocument(widget.document.jsonDocument);
      _findBarPresentation = null;
      _titleFocusNode.unfocus();
    } else if (!_titleFocusNode.hasFocus &&
        widget.document.title != _titleController.text) {
      _replaceTitleText(widget.document.title);
    }
    if (oldWidget.active != widget.active ||
        oldWidget.onOpenDocumentLink != widget.onOpenDocumentLink) {
      _syncDocumentLinkHandler();
    }
    if (oldWidget.active && !widget.active) {
      _findBarPresentation = null;
    }
  }

  @override
  void dispose() {
    _titleSaveDebounce?.cancel();
    _DocumentLinkLaunchDispatcher.deactivate(_linkHandlerOwner);
    _titleFocusNode
      ..removeListener(_handleTitleFocusChange)
      ..dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _handleTitleFocusChange() {
    if (!mounted || _editingTitle == _titleFocusNode.hasFocus) {
      return;
    }
    setState(() => _editingTitle = _titleFocusNode.hasFocus);
  }

  void _replaceTitleText(String title) {
    _titleText = title;
    _titleController.value = TextEditingValue(
      text: title,
      selection: TextSelection.collapsed(offset: title.length),
    );
  }

  void _syncDocumentLinkHandler() {
    if (!widget.active) {
      _DocumentLinkLaunchDispatcher.deactivate(_linkHandlerOwner);
      return;
    }
    _DocumentLinkLaunchDispatcher.activate(
      _linkHandlerOwner,
      _handleDocumentLinkLaunch,
    );
  }

  Future<bool> _handleDocumentLinkLaunch(String? href) async {
    final documentId = nxDocumentIdFromHref(href);
    if (documentId != null && widget.onOpenDocumentLink != null) {
      widget.onOpenDocumentLink!(documentId);
      return true;
    }
    return false;
  }

  void _scheduleTitleSave(String title) {
    setState(() => _titleText = title);
    widget.onTitleChanged?.call(title);
    _draftDocument = _draftDocument.copyWith(title: title);
    _titleSaveDebounce?.cancel();
    _titleSaveDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      await ref
          .read(documentMutationControllerProvider)
          .saveDraft(_draftDocument);
    });
  }

  void _setEditorMode(_DocumentEditorMode mode) {
    if (_editorMode == mode) {
      return;
    }
    setState(() => _editorMode = mode);
  }

  void _setFindBarPresentation(_EditorFindBarPresentation? presentation) {
    if (!mounted) return;
    if (_findBarPresentation == presentation) return;
    setState(() => _findBarPresentation = presentation);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 700 ? 30.0 : 38.0;
    final imageAssetService = ref.watch(documentImageAssetServiceProvider);
    final readMode = _editorMode == _DocumentEditorMode.read;
    return Focus(
      onKeyEvent: _handleShellKeyEvent,
      child: Column(
        children: <Widget>[
          if (widget.contextBar != null) widget.contextBar!,
          Expanded(
            child: ColoredBox(
              color: readMode ? _readModeBackgroundColor() : Colors.transparent,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.horizontalPadding,
                  54,
                  widget.horizontalPadding,
                  0,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: readMode ? 720 : double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: <Widget>[
                              if (widget.canNavigateBack &&
                                  widget.onNavigateBack != null)
                                TextButton.icon(
                                  onPressed: widget.onNavigateBack,
                                  icon: const Icon(Icons.arrow_back, size: 16),
                                  label: const Text('Back'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.muted,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              const Spacer(),
                              if (widget.active)
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 120),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: _findBarPresentation == null
                                      ? _ReadEditModeToggle(
                                          key: const ValueKey<String>(
                                            'mode-toggle',
                                          ),
                                          mode: _editorMode,
                                          onChanged: _setEditorMode,
                                        )
                                      : _EditorFindBar(
                                          key: ValueKey<int>(
                                            _findBarPresentation!.serial,
                                          ),
                                          searchService: _findBarPresentation!
                                              .searchService,
                                          onClose:
                                              _findBarPresentation!.onClose,
                                        ),
                                ),
                            ],
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fittedTitleSize = _fittedTitleFontSize(
                              context: context,
                              text: _titleText,
                              maxWidth: constraints.maxWidth - 4,
                              baseSize: titleSize,
                            );
                            final titleStyle = TextStyle(
                              color: AppColors.text,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w600,
                              height: 1.16,
                              letterSpacing: 0,
                            );
                            return SizedBox(
                              width: constraints.maxWidth,
                              height: titleSize * 1.26,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 90),
                                child: _editingTitle
                                    ? TextField(
                                        key: ValueKey<String>(
                                          'title-editor-${widget.document.id}',
                                        ),
                                        controller: _titleController,
                                        focusNode: _titleFocusNode,
                                        cursorColor: _editorMode.showsCaret
                                            ? AppColors.text
                                            : Colors.transparent,
                                        onChanged: _scheduleTitleSave,
                                        onSubmitted: (_) =>
                                            _titleFocusNode.unfocus(),
                                        onTapOutside: (_) =>
                                            _titleFocusNode.unfocus(),
                                        maxLines: 1,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        style: titleStyle.copyWith(
                                          fontSize: fittedTitleSize,
                                        ),
                                      )
                                    : MouseRegion(
                                        key: ValueKey<String>(
                                          'title-display-${widget.document.id}',
                                        ),
                                        cursor: SystemMouseCursors.text,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            setState(
                                              () => _editingTitle = true,
                                            );
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (!mounted) return;
                                                  _titleFocusNode
                                                      .requestFocus();
                                                  _titleController.selection =
                                                      TextSelection.collapsed(
                                                        offset: _titleController
                                                            .text
                                                            .length,
                                                      );
                                                });
                                          },
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: AutoSizeText(
                                              _titleText.trim().isEmpty
                                                  ? 'Untitled document'
                                                  : _titleText.trim(),
                                              maxLines: 1,
                                              minFontSize: 8,
                                              stepGranularity: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: titleStyle,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        Expanded(
                          child: _NxAppFlowyEditor(
                            document: widget.document,
                            editorMode: _editorMode,
                            active: widget.active,
                            searchLinkableModels:
                                ({required modelType, required query}) {
                                  return ref
                                      .read(documentRepositoryProvider)
                                      .searchLinkableModels(
                                        modelType: modelType,
                                        query: query,
                                      );
                                },
                            onLinkableModelSelected: (modelType, model) async {
                              await ref
                                  .read(documentMutationControllerProvider)
                                  .attachLinkedModel(
                                    documentId: widget.document.id,
                                    modelType: modelType,
                                    modelId: model.id,
                                    model: model,
                                  );
                            },
                            createLinkedDocument: (title) async {
                              final document = await ref
                                  .read(documentMutationControllerProvider)
                                  .createDocument(title: title);
                              return LinkedModel(
                                id: document.id,
                                name: document.title,
                                modelType: LinkableModelType.document.kgqlName,
                              );
                            },
                            uploadDocumentImage: imageAssetService == null
                                ? null
                                : (source) {
                                    return imageAssetService.storeImageSource(
                                      documentId: widget.document.id,
                                      source: source,
                                    );
                                  },
                            deleteDocumentImage: imageAssetService == null
                                ? null
                                : (url) async {
                                    await imageAssetService.deleteImageUrl(url);
                                  },
                            resolveDocumentImage:
                                imageAssetService?.resolveImageUrl,
                            documentImageBaseUrl:
                                imageAssetService?.imageBaseUrl,
                            onFindBarChanged: _setFindBarPresentation,
                            onChanged: (updated, policy) async {
                              _draftDocument = _draftDocument.copyWith(
                                document: updated.document,
                                jsonDocument: updated.jsonDocument,
                                wordCount: updated.wordCount,
                                excerpt: updated.excerpt,
                              );
                              await ref
                                  .read(documentMutationControllerProvider)
                                  .saveDraft(_draftDocument, policy: policy);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleShellKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.active || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final isFind =
        event.logicalKey == LogicalKeyboardKey.keyF &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed);
    if (!isFind) {
      return KeyEventResult.ignored;
    }
    _openEditorFind();
    return KeyEventResult.handled;
  }

  void _openEditorFind() {
    editorFindRequestNotifier.value = EditorFindRequest(
      documentId: widget.document.id,
      serial: editorFindRequestNotifier.value.serial + 1,
    );
  }
}

double _fittedTitleFontSize({
  required BuildContext context,
  required String text,
  required double maxWidth,
  required double baseSize,
}) {
  final title = text.trim().isEmpty ? 'Untitled document' : text.trim();
  const minSize = 12.0;
  if (maxWidth <= 0 || title.isEmpty) {
    return baseSize;
  }

  final minWidth = _titleWidth(
    context: context,
    text: title,
    fontSize: minSize,
  );
  if (minWidth > maxWidth && minWidth > 0) {
    return (minSize * maxWidth / minWidth).clamp(8.0, minSize).toDouble();
  }

  var low = minSize;
  var high = baseSize;
  for (var i = 0; i < 8; i++) {
    final mid = (low + high) / 2;
    if (_titleFits(
      context: context,
      text: title,
      maxWidth: maxWidth,
      fontSize: mid,
    )) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return low;
}

bool _titleFits({
  required BuildContext context,
  required String text,
  required double maxWidth,
  required double fontSize,
}) {
  return _titleWidth(context: context, text: text, fontSize: fontSize) <=
      maxWidth;
}

double _titleWidth({
  required BuildContext context,
  required String text,
  required double fontSize,
}) {
  final textScaler = MediaQuery.textScalerOf(context);
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.16,
        letterSpacing: 0,
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: textScaler,
  )..layout(maxWidth: double.infinity);
  return painter.width;
}

class _NxAppFlowyEditor extends StatefulWidget {
  const _NxAppFlowyEditor({
    required this.document,
    required this.editorMode,
    required this.onChanged,
    required this.onFindBarChanged,
    required this.searchLinkableModels,
    required this.onLinkableModelSelected,
    required this.createLinkedDocument,
    this.uploadDocumentImage,
    this.deleteDocumentImage,
    this.resolveDocumentImage,
    this.documentImageBaseUrl,
    this.active = true,
  });

  final NxDocument document;
  final _DocumentEditorMode editorMode;
  final bool active;
  final Future<void> Function(NxDocument document, DraftSavePolicy policy)
  onChanged;
  final ValueChanged<_EditorFindBarPresentation?> onFindBarChanged;
  final Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels;
  final Future<void> Function(LinkableModelType modelType, LinkedModel model)
  onLinkableModelSelected;
  final Future<LinkedModel> Function(String title) createLinkedDocument;
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
  bool _saveNextTransactionImmediately = false;
  bool _showFindBar = false;
  late NxDocument _editorDocument;
  late int _editorDocumentId;
  int? _handledHeadingScrollRequestSerial;
  int _handledFindRequestSerial = 0;
  int _findBarOpenSerial = 0;
  int _scrollAnchorRestoreAttempts = 0;
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
    if (oldWidget.editorMode != widget.editorMode) {
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
    _clearActiveHeading();
    _disposeEditor();
    super.dispose();
  }

  void _createEditor() {
    registerNxHighlightNoteAttribute();
    _editorDocument = widget.document;
    _editorDocumentId = widget.document.id;
    _lastSavedScrollAnchor = null;
    _scrollAnchorSaveEnabled = false;
    _showFindBar = false;
    _editorState = EditorState(
      document: _documentFromDocument(widget.document),
    );
    _editorState.editable = true;
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
    unawaited(_saveScrollAnchorNow());
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

  void _handleEditorScrolled() {
    _scheduleScrollAnchorSave();
  }

  void _handleVisibleItemPositionsChanged() {
    _scheduleActiveHeadingPublish();
    _scheduleScrollAnchorSave();
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
    unawaited(widget.onChanged(_currentDraftDocument(), policy));
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
    return <CommandShortcutEvent>[
      CommandShortcutEvent(
        key: 'nx open editor find',
        getDescription: () => 'Find in document',
        command: 'ctrl+f',
        macOSCommand: 'cmd+f',
        handler: (editorState) {
          _openFindBar();
          return KeyEventResult.handled;
        },
      ),
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
    if (!mounted || !widget.active || !_scrollAnchorSaveEnabled) {
      return;
    }
    final anchor = _currentScrollAnchor();
    if (anchor == null) {
      return;
    }
    if (anchor == _lastSavedScrollAnchor) {
      return;
    }
    _lastSavedScrollAnchor = anchor;
    await widget.onChanged(
      _currentDraftDocument(scrollAnchor: anchor),
      DraftSavePolicy.deferred,
    );
  }

  void _handleEditorModeChanged() {
    _editorState.editable = true;
    final anchor = _currentScrollAnchor();
    if (anchor != null) {
      _lastSavedScrollAnchor = anchor;
    }
    unawaited(
      widget.onChanged(
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

  void _clearActiveHeading() {
    final current = documentActiveHeadingNotifier.value;
    if (current?.documentId == widget.document.id) {
      documentActiveHeadingNotifier.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showsCaret = widget.editorMode.showsCaret;
    final editorStyle = _editorStyle(
      widget.editorMode,
    ).copyWith(cursorColor: showsCaret ? AppColors.text : Colors.transparent);
    final editor = AppFlowyEditor(
      editable: true,
      editorState: _editorState,
      editorScrollController: _scrollController,
      editorStyle: editorStyle,
      blockComponentBuilders: nxBlockComponentBuilders(
        deleteDocumentImage: widget.deleteDocumentImage,
        resolveDocumentImage: widget.resolveDocumentImage,
        documentImageBaseUrl: widget.documentImageBaseUrl,
      ),
      characterShortcutEvents: <CharacterShortcutEvent>[
        ...standardCharacterShortcutEvents.where(
          (event) => event.key != 'show the slash menu',
        ),
        nxSlashCommand(
          searchLinkableModels: widget.searchLinkableModels,
          createLinkedDocument: widget.createLinkedDocument,
          onLinkableModelSelected: widget.onLinkableModelSelected,
          uploadDocumentImage: widget.uploadDocumentImage,
        ),
      ],
      commandShortcutEvents: _commandShortcutEvents(),
      footer: const SizedBox(height: 120),
    );
    return FloatingToolbar(
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
          createDocument: widget.createLinkedDocument,
          onLinkableModelSelected: widget.onLinkableModelSelected,
        ),
        ...alignmentItems,
      ],
      tooltipBuilder: (context, _, message, child) {
        return Tooltip(message: message, preferBelow: false, child: child);
      },
      child: editor,
    );
  }
}

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

class NxSelectionFormattingToolbar extends StatefulWidget {
  const NxSelectionFormattingToolbar({
    required this.editorState,
    required this.editorScrollController,
    required this.child,
    super.key,
  });

  final EditorState editorState;
  final EditorScrollController editorScrollController;
  final Widget child;

  @override
  State<NxSelectionFormattingToolbar> createState() =>
      _NxSelectionFormattingToolbarState();
}

class _NxSelectionFormattingToolbarState
    extends State<NxSelectionFormattingToolbar> {
  static const _toolbarHeight = 34.0;
  OverlayEntry? _overlayEntry;
  Selection? _toolbarSelection;
  Timer? _showTimer;

  EditorState get _editorState => widget.editorState;

  @override
  void initState() {
    super.initState();
    _editorState.selectionNotifier.addListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.addListener(_hideToolbar);
  }

  @override
  void didUpdateWidget(covariant NxSelectionFormattingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      oldWidget.editorState.selectionNotifier.removeListener(
        _onSelectionChanged,
      );
      widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    }
    if (oldWidget.editorScrollController != widget.editorScrollController) {
      oldWidget.editorScrollController.offsetNotifier.removeListener(
        _hideToolbar,
      );
      widget.editorScrollController.offsetNotifier.addListener(_hideToolbar);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideToolbar();
    _editorState.selectionNotifier.removeListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.removeListener(_hideToolbar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onSelectionChanged() {
    final selection = _editorState.selection;
    if (selection == null ||
        selection.isCollapsed ||
        _editorState.selectionType == SelectionType.block ||
        !_selectionContainsText(selection)) {
      _hideToolbar();
      return;
    }

    _toolbarSelection = selection.normalized;
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 80), _showToolbar);
  }

  bool _selectionContainsText(Selection selection) {
    final nodes = _editorState.getNodesInSelection(selection);
    return nodes.any((node) {
      final delta = node.delta;
      return delta != null && delta.isNotEmpty;
    });
  }

  void _showToolbar() {
    final selection = _toolbarSelection;
    if (selection == null || !mounted) {
      return;
    }
    final rects = _editorState.selectionRects();
    if (rects.isEmpty) {
      return;
    }

    final rect = rects.reduce((a, b) => a.top <= b.top ? a : b);
    final overlay = Overlay.of(context, rootOverlay: true);
    final left = rect.center.dx - 95;
    final top = rect.top - _toolbarHeight - 8;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left < 8 ? 8 : left,
        top: top < 8 ? rect.bottom + 8 : top,
        child: _NxFormattingToolbarSurface(
          selection: selection,
          editorState: _editorState,
          onClose: _hideToolbar,
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _hideToolbar() {
    _showTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _NxFormattingToolbarSurface extends StatelessWidget {
  const _NxFormattingToolbarSurface({
    required this.selection,
    required this.editorState,
    required this.onClose,
  });

  final Selection selection;
  final EditorState editorState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.floating,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _formatButton('B', 'bold', FontWeight.w700),
              _formatButton('I', 'italic', FontWeight.w500),
              _formatButton('U', 'underline', FontWeight.w500),
              _formatButton('S', 'strikethrough', FontWeight.w500),
              _formatButton('</>', 'code', FontWeight.w600, wide: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatButton(
    String label,
    String attribute,
    FontWeight fontWeight, {
    bool wide = false,
  }) {
    return Tooltip(
      message: attribute,
      preferBelow: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _toggle(attribute),
        child: SizedBox(
          width: wide ? 38 : 28,
          height: 28,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.onFloating,
                fontSize: wide ? 11 : 13,
                fontWeight: fontWeight,
                fontStyle: attribute == 'italic' ? FontStyle.italic : null,
                decoration: attribute == 'underline'
                    ? TextDecoration.underline
                    : attribute == 'strikethrough'
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: AppColors.onFloating,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggle(String attribute) {
    editorState.toggleAttribute(attribute, selection: selection);
  }
}

EditorStyle _editorStyle(_DocumentEditorMode mode) {
  final readMode = mode == _DocumentEditorMode.read;
  final bodyStyle = readMode
      ? TextStyle(
          color: _readModeTextColor(),
          fontFamily: 'Georgia',
          fontSize: 17,
          height: 1.5,
        )
      : TextStyle(color: AppColors.editorText, fontSize: 16, height: 1.62);
  final lineHeight = readMode ? 1.5 : 1.62;
  return EditorStyle.desktop(
    cursorColor: AppColors.text,
    selectionColor: const Color(0x333B82F6),
    padding: EdgeInsets.zero,
    textSpanDecorator: nxHighlightNoteTextSpanDecorator,
    textSpanOverlayBuilder: nxHighlightNoteOverlayBuilder,
    textStyleConfiguration: TextStyleConfiguration(
      text: bodyStyle,
      bold: const TextStyle(fontWeight: FontWeight.w700),
      italic: const TextStyle(fontStyle: FontStyle.italic),
      underline: const TextStyle(decoration: TextDecoration.underline),
      strikethrough: const TextStyle(decoration: TextDecoration.lineThrough),
      href: TextStyle(
        foreground: Paint()..color = AppColors.blue,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.blue,
      ),
      code: TextStyle(
        color: AppColors.text,
        backgroundColor: AppColors.subtle,
        fontFamily: 'monospace',
      ),
      lineHeight: lineHeight,
    ),
  );
}

Color _readModeBackgroundColor() {
  return AppColors.isDark ? const Color(0xff171512) : const Color(0xfff6f5f1);
}

Color _readModeTextColor() {
  return AppColors.isDark ? const Color(0xffe8e1d5) : const Color(0xff25231f);
}

class EditorContextBar extends StatelessWidget {
  const EditorContextBar({
    required this.resultContext,
    required this.activeDocumentId,
    required this.onBack,
    required this.onClear,
    super.key,
  });

  final DocumentResultContext resultContext;
  final int activeDocumentId;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final index = resultContext.resultIds.indexOf(activeDocumentId);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.muted,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('Back to ${resultContext.title}'),
          ),
          const Spacer(),
          Text(
            '${index + 1} of ${resultContext.resultIds.length}',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: Icon(Icons.close, size: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
