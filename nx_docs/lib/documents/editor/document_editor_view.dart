import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:nx_docs/documents/document_session.dart';
import 'package:nx_docs/workspace/layout.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/document_providers.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/companion/note_companion.dart';
import 'package:nx_docs/documents/document_actions.dart';
import 'package:nx_docs/documents/editor/document_text_scale.dart';
import 'package:nx_docs/documents/editor/nx_appflowy_blocks.dart';
import 'package:nx_docs/documents/editor/nx_color_toolbar.dart';
import 'package:nx_docs/documents/editor/nx_document_link.dart';
import 'package:nx_docs/documents/editor/nx_highlight_notes.dart';
// import 'package:nx_docs/documents/editor/offline_sync_status_label.dart';

part 'editor_canvas.dart';
part 'editor_navigation.dart';
part 'editor_toolbar.dart';

class DocumentEditorView extends ConsumerWidget {
  const DocumentEditorView({
    required this.documentId,
    this.contextBar,
    this.onTitleChanged,
    this.onOpenDocumentLink,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.horizontalPadding = 48,
    this.contentTopPadding = 54,
    this.showDocumentTitle = true,
    this.active = true,
    this.readOnly = false,
    this.showCompanion = true,
    super.key,
  });

  final int documentId;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<int>? onOpenDocumentLink;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final double horizontalPadding;
  final double contentTopPadding;
  final bool showDocumentTitle;
  final bool active;
  final bool readOnly;
  final bool showCompanion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kDebugMode) {
      debugPrint('[nx_docs editor lifecycle] view-build document=$documentId');
    }
    final demand = active
        ? ref.watch(documentDemandProvider(documentId))
        : const AsyncValue<void>.data(null);
    final asyncState = ref.watch(documentSessionStateProvider(documentId));
    return asyncState.when(
      data: (sessionState) {
        final document = sessionState.document;
        if (document == null) {
          return Center(
            child: Text(
              demand.hasError ||
                      sessionState.phase == DocumentPhase.unavailableOffline
                  ? 'This document has not been downloaded on this device.'
                  : sessionState.phase == DocumentPhase.notFound
                  ? 'Document not found'
                  : 'Opening document…',
            ),
          );
        }
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: DocumentEditorBody(
                document: document,
                changeOrigin: sessionState.origin,
                contextBar: contextBar,
                onTitleChanged: onTitleChanged,
                onOpenDocumentLink: onOpenDocumentLink,
                canNavigateBack: canNavigateBack,
                onNavigateBack: onNavigateBack,
                horizontalPadding: horizontalPadding,
                contentTopPadding: contentTopPadding,
                showDocumentTitle: showDocumentTitle,
                active: active,
                readOnly: readOnly,
              ),
            ),
            if (active && showCompanion)
              Positioned(
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  left: false,
                  child: NoteCompanion(
                    document: document,
                    onAudioBlockChanged: (block) {
                      documentAudioBlockRequestNotifier.value =
                          DocumentAudioBlockRequest(
                            documentId: document.id,
                            blockIndex: block.blockIndex,
                            blockKey: block.blockKey,
                          );
                      _saveAudioScrollAnchor(ref, document, block);
                    },
                  ),
                ),
              ),
          ],
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
    this.changeOrigin = DocumentChangeOrigin.localCache,
    this.contextBar,
    this.onTitleChanged,
    this.onOpenDocumentLink,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.horizontalPadding = 48,
    this.contentTopPadding = 54,
    this.showDocumentTitle = true,
    this.active = true,
    this.readOnly = false,
    super.key,
  });

  final NxDocument document;
  final DocumentChangeOrigin changeOrigin;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<int>? onOpenDocumentLink;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final double horizontalPadding;
  final double contentTopPadding;
  final bool showDocumentTitle;
  final bool active;
  final bool readOnly;

  @override
  ConsumerState<DocumentEditorBody> createState() => _DocumentEditorBodyState();
}

typedef _LaunchUrlHandler = Future<bool> Function(String? href);

class EditorFindRequest {
  const EditorFindRequest({required this.documentId, required this.serial});

  final int documentId;
  final int serial;
}

class DocumentAudioBlockRequest {
  const DocumentAudioBlockRequest({
    required this.documentId,
    required this.blockIndex,
    required this.blockKey,
  });

  final int documentId;
  final int blockIndex;
  final String blockKey;
}

final documentAudioBlockRequestNotifier =
    ValueNotifier<DocumentAudioBlockRequest?>(null);

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
    if (kDebugMode) {
      debugPrint(
        '[nx_docs editor lifecycle] body-init '
        'document=${widget.document.id}',
      );
    }
    _draftDocument = widget.document;
    _titleText = widget.document.title;
    _editorMode = widget.readOnly
        ? _DocumentEditorMode.read
        : _editorModeFromJsonDocument(widget.document.jsonDocument);
    _titleController = TextEditingController(text: _titleText);
    _titleFocusNode = FocusNode()..addListener(_handleTitleFocusChange);
    _syncDocumentLinkHandler();
  }

  @override
  void didUpdateWidget(covariant DocumentEditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kDebugMode) {
      debugPrint(
        '[nx_docs editor lifecycle] body-update '
        'old=${oldWidget.document.id} new=${widget.document.id} '
        'titleChanged=${oldWidget.document.title != widget.document.title} '
        'contentChanged='
        '${oldWidget.document.jsonDocument != widget.document.jsonDocument}',
      );
    }
    if (oldWidget.document.id != widget.document.id) {
      _titleSaveDebounce?.cancel();
      _draftDocument = widget.document;
      _replaceTitleText(widget.document.title);
      _editorMode = widget.readOnly
          ? _DocumentEditorMode.read
          : _editorModeFromJsonDocument(widget.document.jsonDocument);
      _findBarPresentation = null;
      _titleFocusNode.unfocus();
    } else if (!_titleFocusNode.hasFocus &&
        widget.document.title != _titleController.text) {
      _replaceTitleText(widget.document.title);
    }
    if (oldWidget.document.id == widget.document.id) {
      _draftDocument = _isRemoteOrigin(widget.changeOrigin)
          ? widget.document
          : _draftDocument.copyWith(
              links: widget.document.links,
              readingState: widget.document.readingState,
              bookRank: widget.document.bookRank,
              clearBookRank: widget.document.bookRank == null,
            );
    }
    if (oldWidget.active != widget.active ||
        oldWidget.onOpenDocumentLink != widget.onOpenDocumentLink) {
      _syncDocumentLinkHandler();
    }
    if (oldWidget.active && !widget.active) {
      _findBarPresentation = null;
    }
    if (!oldWidget.readOnly && widget.readOnly) {
      _editorMode = _DocumentEditorMode.read;
      _titleFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      debugPrint(
        '[nx_docs editor lifecycle] body-dispose '
        'document=${widget.document.id}',
      );
    }
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
    if (widget.readOnly) return;
    setState(() => _titleText = title);
    widget.onTitleChanged?.call(title);
    _draftDocument = _draftDocument.copyWith(title: title);
    _titleSaveDebounce?.cancel();
    unawaited(
      ref.read(documentMutationControllerProvider).saveDraft(_draftDocument),
    );
  }

  void _setEditorMode(_DocumentEditorMode mode) {
    if (widget.readOnly) return;
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
    final mutationController = ref.read(documentMutationControllerProvider);
    final documentTextScale = ref.watch(documentTextScaleProvider);
    final readMode = _editorMode == _DocumentEditorMode.read;
    final showEditorHeader =
        (widget.canNavigateBack && widget.onNavigateBack != null) ||
        !widget.readOnly ||
        _findBarPresentation != null;
    return Focus(
      onKeyEvent: _handleShellKeyEvent,
      child: Column(
        children: <Widget>[
          if (widget.contextBar != null) widget.contextBar!,
          // Temporarily hidden while the sync-status presentation is revised.
          // const Align(
          //   alignment: Alignment.centerRight,
          //   child: Padding(
          //     padding: EdgeInsets.only(right: 16, top: 4),
          //     child: OfflineSyncStatusLabel(),
          //   ),
          // ),
          Expanded(
            child: ColoredBox(
              color: readMode ? _readModeBackgroundColor() : Colors.transparent,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.horizontalPadding,
                  widget.contentTopPadding,
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
                        if (showEditorHeader)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: <Widget>[
                                if (widget.canNavigateBack &&
                                    widget.onNavigateBack != null)
                                  TextButton.icon(
                                    onPressed: widget.onNavigateBack,
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 16,
                                    ),
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
                                        ? widget.readOnly
                                              ? const SizedBox.shrink()
                                              : _ReadEditModeToggle(
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
                        if (widget.showDocumentTitle)
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
                                  child: _editingTitle && !widget.readOnly
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
                                          cursor: widget.readOnly
                                              ? MouseCursor.defer
                                              : SystemMouseCursors.text,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: widget.readOnly
                                                ? null
                                                : () {
                                                    setState(
                                                      () =>
                                                          _editingTitle = true,
                                                    );
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback((
                                                          _,
                                                        ) {
                                                          if (!mounted) return;
                                                          _titleFocusNode
                                                              .requestFocus();
                                                          _titleController
                                                                  .selection =
                                                              TextSelection.collapsed(
                                                                offset:
                                                                    _titleController
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
                        if (widget.showDocumentTitle)
                          const SizedBox(height: 28),
                        Expanded(
                          child: _NxAppFlowyEditor(
                            document: widget.document,
                            changeOrigin: widget.changeOrigin,
                            textScaleFactor: documentTextScale,
                            editorMode: _editorMode,
                            readOnly: widget.readOnly,
                            active: widget.active,
                            searchLinkableModels:
                                ({required modelType, required query}) {
                                  final service = ref.read(
                                    documentLinkServiceProvider,
                                  );
                                  if (service == null) {
                                    return Future.value(const <LinkedModel>[]);
                                  }
                                  return service.search(
                                    modelType: modelType,
                                    query: query,
                                  );
                                },
                            onLinkableModelSelected: widget.readOnly
                                ? null
                                : (modelType, model) async {
                                    await ref
                                        .read(
                                          documentMutationControllerProvider,
                                        )
                                        .attachLinkedModel(
                                          documentId: widget.document.id,
                                          modelType: modelType,
                                          modelId: model.id,
                                          model: model,
                                        );
                                  },
                            createLinkedDocument: widget.readOnly
                                ? null
                                : (title) async {
                                    final document = await ref
                                        .read(
                                          documentMutationControllerProvider,
                                        )
                                        .createDocument(title: title);
                                    return LinkedModel(
                                      id: document.id,
                                      name: document.title,
                                      modelType:
                                          LinkableModelType.document.kgqlName,
                                    );
                                  },
                            uploadDocumentImage:
                                widget.readOnly || imageAssetService == null
                                ? null
                                : (source) {
                                    return imageAssetService.storeImageSource(
                                      documentId: widget.document.id,
                                      source: source,
                                    );
                                  },
                            deleteDocumentImage:
                                widget.readOnly || imageAssetService == null
                                ? null
                                : (url) async {
                                    await imageAssetService.deleteImageUrl(url);
                                  },
                            resolveDocumentImage:
                                imageAssetService?.resolveImageUrl,
                            documentImageBaseUrl:
                                imageAssetService?.imageBaseUrl,
                            onFindBarChanged: _setFindBarPresentation,
                            onChanged: widget.readOnly
                                ? null
                                : (updated, policy) async {
                                    _draftDocument = _draftDocument.copyWith(
                                      document: updated.document,
                                      jsonDocument: updated.jsonDocument,
                                      wordCount: updated.wordCount,
                                      excerpt: updated.excerpt,
                                    );
                                    await mutationController.saveDraft(
                                      _draftDocument,
                                      policy: policy,
                                    );
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

void _saveAudioScrollAnchor(
  WidgetRef ref,
  NxDocument document,
  DocumentAudioBlockTiming block,
) {
  final existing = _scrollAnchorFromJsonDocument(document.jsonDocument);
  if (existing?.blockKey == block.blockKey) return;
  final anchor = _DocumentScrollAnchor(
    documentId: document.id,
    blockIndex: block.blockIndex,
    blockKey: block.blockKey,
    alignment: 0.18,
  );
  final jsonDocument = <String, dynamic>{
    ...document.jsonDocument,
    'view_state': _jsonDocumentViewState(
      document.jsonDocument,
      editorMode: _editorModeFromJsonDocument(document.jsonDocument),
      scrollAnchor: anchor,
    ),
  };
  unawaited(
    ref
        .read(documentMutationControllerProvider)
        .saveDraft(
          document.copyWith(jsonDocument: jsonDocument),
          policy: DraftSavePolicy.deferred,
        ),
  );
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
