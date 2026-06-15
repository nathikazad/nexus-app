import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_result_context.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/features/essay/essay_actions.dart';
import 'package:nx_notes/features/editor/nx_appflowy_blocks.dart';
import 'package:nx_notes/features/editor/nx_color_toolbar.dart';
import 'package:nx_notes/features/editor/nx_essay_link.dart';
import 'package:nx_notes/features/editor/nx_highlight_notes.dart';

class EssayEditorView extends ConsumerWidget {
  const EssayEditorView({
    required this.essayId,
    this.contextBar,
    this.onTitleChanged,
    this.onOpenEssayLink,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.horizontalPadding = 48,
    this.active = true,
    super.key,
  });

  final int essayId;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<int>? onOpenEssayLink;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final double horizontalPadding;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEssay = ref.watch(essayByIdProvider(essayId));
    return asyncEssay.when(
      data: (essay) {
        if (essay == null) {
          return const Center(child: Text('Essay not found'));
        }
        return EssayEditorBody(
          essay: essay,
          contextBar: contextBar,
          onTitleChanged: onTitleChanged,
          onOpenEssayLink: onOpenEssayLink,
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

class EssayEditorBody extends ConsumerStatefulWidget {
  const EssayEditorBody({
    required this.essay,
    this.contextBar,
    this.onTitleChanged,
    this.onOpenEssayLink,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.horizontalPadding = 48,
    this.active = true,
    super.key,
  });

  final Essay essay;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<int>? onOpenEssayLink;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final double horizontalPadding;
  final bool active;

  @override
  ConsumerState<EssayEditorBody> createState() => _EssayEditorBodyState();
}

typedef _LaunchUrlHandler = Future<bool> Function(String? href);

class _EssayLinkLaunchDispatcher {
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

class _EssayEditorBodyState extends ConsumerState<EssayEditorBody> {
  Timer? _titleSaveDebounce;
  late Essay _draftEssay;
  late String _titleText;
  final Object _linkHandlerOwner = Object();

  @override
  void initState() {
    super.initState();
    _draftEssay = widget.essay;
    _titleText = widget.essay.title;
    _syncEssayLinkHandler();
  }

  @override
  void didUpdateWidget(covariant EssayEditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.essay.id != widget.essay.id) {
      _titleSaveDebounce?.cancel();
      _draftEssay = widget.essay;
      _titleText = widget.essay.title;
    }
    if (oldWidget.active != widget.active ||
        oldWidget.onOpenEssayLink != widget.onOpenEssayLink) {
      _syncEssayLinkHandler();
    }
  }

  @override
  void dispose() {
    _titleSaveDebounce?.cancel();
    _EssayLinkLaunchDispatcher.deactivate(_linkHandlerOwner);
    super.dispose();
  }

  void _syncEssayLinkHandler() {
    if (!widget.active) {
      _EssayLinkLaunchDispatcher.deactivate(_linkHandlerOwner);
      return;
    }
    _EssayLinkLaunchDispatcher.activate(
      _linkHandlerOwner,
      _handleEssayLinkLaunch,
    );
  }

  Future<bool> _handleEssayLinkLaunch(String? href) async {
    final essayId = nxEssayIdFromHref(href);
    if (essayId != null && widget.onOpenEssayLink != null) {
      widget.onOpenEssayLink!(essayId);
      return true;
    }
    return false;
  }

  void _scheduleTitleSave(String title) {
    setState(() => _titleText = title);
    widget.onTitleChanged?.call(title);
    _draftEssay = _draftEssay.copyWith(title: title);
    _titleSaveDebounce?.cancel();
    _titleSaveDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      await ref.read(essayMutationControllerProvider).saveDraft(_draftEssay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 700 ? 30.0 : 38.0;
    return Column(
      children: <Widget>[
        if (widget.contextBar != null) widget.contextBar!,
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.horizontalPadding,
              54,
              widget.horizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (widget.canNavigateBack && widget.onNavigateBack != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: TextButton.icon(
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
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fittedTitleSize = _fittedTitleFontSize(
                      context: context,
                      text: _titleText,
                      maxWidth: constraints.maxWidth,
                      baseSize: titleSize,
                    );
                    return TextFormField(
                      key: ValueKey<int>(widget.essay.id),
                      initialValue: widget.essay.title,
                      onChanged: _scheduleTitleSave,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: fittedTitleSize,
                        fontWeight: FontWeight.w600,
                        height: 1.16,
                        letterSpacing: 0,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: NxAppFlowyEditor(
                    essay: widget.essay,
                    active: widget.active,
                    searchLinkableModels:
                        ({required modelType, required query}) {
                          return ref
                              .read(essayRepositoryProvider)
                              .searchLinkableModels(
                                modelType: modelType,
                                query: query,
                              );
                        },
                    onLinkableModelSelected: (modelType, model) async {
                      await ref
                          .read(essayMutationControllerProvider)
                          .attachLinkedModel(
                            essayId: widget.essay.id,
                            modelType: modelType,
                            modelId: model.id,
                            model: model,
                          );
                    },
                    createLinkedEssay: (title) async {
                      final essay = await ref
                          .read(essayMutationControllerProvider)
                          .createEssay(title: title);
                      return LinkedModel(
                        id: essay.id,
                        name: essay.title,
                        modelType: LinkableModelType.essay.kgqlName,
                      );
                    },
                    onChanged: (updated, policy) async {
                      _draftEssay = _draftEssay.copyWith(
                        document: updated.document,
                        jsonDocument: updated.jsonDocument,
                        wordCount: updated.wordCount,
                        excerpt: updated.excerpt,
                      );
                      await ref
                          .read(essayMutationControllerProvider)
                          .saveDraft(_draftEssay, policy: policy);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

double _fittedTitleFontSize({
  required BuildContext context,
  required String text,
  required double maxWidth,
  required double baseSize,
}) {
  final title = text.trim().isEmpty ? 'Untitled essay' : text.trim();
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

class NxAppFlowyEditor extends StatefulWidget {
  const NxAppFlowyEditor({
    required this.essay,
    required this.onChanged,
    required this.searchLinkableModels,
    required this.onLinkableModelSelected,
    required this.createLinkedEssay,
    this.active = true,
    super.key,
  });

  final Essay essay;
  final bool active;
  final Future<void> Function(Essay essay, DraftSavePolicy policy) onChanged;
  final Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels;
  final Future<void> Function(LinkableModelType modelType, LinkedModel model)
  onLinkableModelSelected;
  final Future<LinkedModel> Function(String title) createLinkedEssay;

  @override
  State<NxAppFlowyEditor> createState() => _NxAppFlowyEditorState();
}

class _NxAppFlowyEditorState extends State<NxAppFlowyEditor> {
  static const _caretEditIdleDelay = Duration(seconds: 8);
  static const _caretScrollIdleDelay = Duration(seconds: 5);
  static const _pasteShortcutKeys = <String>{
    'paste the content',
    'paste the content as plain text',
  };

  late EditorState _editorState;
  late EditorScrollController _scrollController;
  StreamSubscription<EditorTransactionValue>? _transactionSubscription;
  Timer? _saveDebounce;
  Timer? _caretIdleTimer;
  Timer? _nextImmediateSaveTimer;
  bool _activeHeadingPublishScheduled = false;
  bool _caretVisible = true;
  bool _saveNextTransactionImmediately = false;
  int? _handledHeadingScrollRequestSerial;

  @override
  void initState() {
    super.initState();
    _createEditor();
  }

  @override
  void didUpdateWidget(covariant NxAppFlowyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.essay.id != widget.essay.id) {
      _disposeEditor();
      _createEditor();
      return;
    }
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _scheduleActiveHeadingPublish();
      } else {
        _clearActiveHeading();
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
    _caretVisible = true;
    _editorState = EditorState(document: _documentFromEssay(widget.essay));
    _scrollController = EditorScrollController(
      editorState: _editorState,
      shrinkWrap: false,
    );
    _scrollController.itemPositionsListener.itemPositions.addListener(
      _scheduleActiveHeadingPublish,
    );
    _scrollController.offsetNotifier.addListener(_handleEditorScrolled);
    _editorState.selectionNotifier.addListener(_handleEditorSelectionChanged);
    essayHeadingScrollRequestNotifier.addListener(_handleHeadingScrollRequest);
    _transactionSubscription = _editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      if (time == TransactionTime.after &&
          !options.inMemoryUpdate &&
          transaction.operations.isNotEmpty) {
        _showCaretTemporarily();
        _scheduleSave(_savePolicyForTransaction(transaction));
        _scheduleActiveHeadingPublish();
      }
    });
    _scheduleCaretHide(_caretEditIdleDelay);
    _scheduleActiveHeadingPublish();
  }

  void _disposeEditor() {
    _caretIdleTimer?.cancel();
    _caretIdleTimer = null;
    _nextImmediateSaveTimer?.cancel();
    _nextImmediateSaveTimer = null;
    _saveNextTransactionImmediately = false;
    _scrollController.itemPositionsListener.itemPositions.removeListener(
      _scheduleActiveHeadingPublish,
    );
    _scrollController.offsetNotifier.removeListener(_handleEditorScrolled);
    _editorState.selectionNotifier.removeListener(
      _handleEditorSelectionChanged,
    );
    essayHeadingScrollRequestNotifier.removeListener(
      _handleHeadingScrollRequest,
    );
    _transactionSubscription?.cancel();
    _scrollController.dispose();
    _editorState.dispose();
  }

  Document _documentFromEssay(Essay essay) {
    if (essay.jsonDocument['format'] == 'appflowy_document') {
      final documentJson = essay.jsonDocument['document'];
      if (documentJson is Map) {
        return Document.fromJson(<String, dynamic>{
          'document': Map<String, dynamic>.from(documentJson),
        });
      }
    }

    if (essay.document.trim().isNotEmpty) {
      return markdownToDocument(essay.document);
    }

    return Document.blank(withInitialText: true);
  }

  void _handleEditorSelectionChanged() {
    _showCaretTemporarily();
  }

  void _handleEditorScrolled() {
    if (_caretVisible && _caretIdleTimer == null) {
      _scheduleCaretHide(_caretScrollIdleDelay);
    }
  }

  void _showCaretTemporarily() {
    if (!mounted) return;
    if (!_caretVisible) {
      setState(() => _caretVisible = true);
    }
    _scheduleCaretHide(_caretEditIdleDelay);
  }

  void _scheduleCaretHide(Duration delay) {
    _caretIdleTimer?.cancel();
    _caretIdleTimer = Timer(delay, _hideCaret);
  }

  void _hideCaret() {
    _caretIdleTimer?.cancel();
    _caretIdleTimer = null;
    if (!mounted || !_caretVisible) return;
    setState(() => _caretVisible = false);
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
    final plainText = _documentPlainText(_editorState.document).trimRight();
    unawaited(
      widget.onChanged(
        widget.essay.copyWith(
          document: plainText,
          jsonDocument: <String, dynamic>{
            ...widget.essay.jsonDocument,
            'format': 'appflowy_document',
            'document': _editorState.document.toJson()['document'],
          },
          wordCount: _countWords(plainText),
          excerpt: _excerptFrom(plainText),
        ),
        policy,
      ),
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

  void _handleHeadingScrollRequest() {
    final request = essayHeadingScrollRequestNotifier.value;
    if (!mounted ||
        !widget.active ||
        request == null ||
        request.essayId != widget.essay.id ||
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
    final current = essayActiveHeadingNotifier.value;
    if (blockIndex == null) {
      if (current?.essayId == widget.essay.id) {
        essayActiveHeadingNotifier.value = null;
      }
      return;
    }
    if (current?.essayId == widget.essay.id &&
        current?.blockIndex == blockIndex) {
      return;
    }
    essayActiveHeadingNotifier.value = EssayActiveHeading(
      essayId: widget.essay.id,
      blockIndex: blockIndex,
    );
  }

  void _clearActiveHeading() {
    final current = essayActiveHeadingNotifier.value;
    if (current?.essayId == widget.essay.id) {
      essayActiveHeadingNotifier.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorStyle = _editorStyle.copyWith(
      cursorColor: _caretVisible ? AppColors.text : Colors.transparent,
    );
    return Listener(
      onPointerDown: (_) => _showCaretTemporarily(),
      child: FloatingToolbar(
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
          buildNxEssayLinkToolbarItem(
            searchLinkableModels: widget.searchLinkableModels,
            createEssay: widget.createLinkedEssay,
            onLinkableModelSelected: widget.onLinkableModelSelected,
          ),
          ...alignmentItems,
        ],
        tooltipBuilder: (context, _, message, child) {
          return Tooltip(message: message, preferBelow: false, child: child);
        },
        child: AppFlowyEditor(
          editorState: _editorState,
          editorScrollController: _scrollController,
          editorStyle: editorStyle,
          blockComponentBuilders: nxBlockComponentBuilders(),
          characterShortcutEvents: <CharacterShortcutEvent>[
            ...standardCharacterShortcutEvents.where(
              (event) => event.key != 'show the slash menu',
            ),
            nxSlashCommand(
              searchLinkableModels: widget.searchLinkableModels,
              createLinkedEssay: widget.createLinkedEssay,
              onLinkableModelSelected: widget.onLinkableModelSelected,
            ),
          ],
          commandShortcutEvents: _commandShortcutEvents(),
          footer: const SizedBox(height: 120),
        ),
      ),
    );
  }
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
          color: AppColors.text,
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
                color: Colors.white,
                fontSize: wide ? 11 : 13,
                fontWeight: fontWeight,
                fontStyle: attribute == 'italic' ? FontStyle.italic : null,
                decoration: attribute == 'underline'
                    ? TextDecoration.underline
                    : attribute == 'strikethrough'
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: Colors.white,
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

const _editorStyle = EditorStyle.desktop(
  cursorColor: AppColors.text,
  selectionColor: Color(0x333B82F6),
  padding: EdgeInsets.zero,
  textSpanDecorator: nxHighlightNoteTextSpanDecorator,
  textSpanOverlayBuilder: nxHighlightNoteOverlayBuilder,
  textStyleConfiguration: TextStyleConfiguration(
    text: TextStyle(color: Color(0xff3f3f46), fontSize: 16, height: 1.62),
    bold: TextStyle(fontWeight: FontWeight.w700),
    italic: TextStyle(fontStyle: FontStyle.italic),
    underline: TextStyle(decoration: TextDecoration.underline),
    strikethrough: TextStyle(decoration: TextDecoration.lineThrough),
    href: TextStyle(
      color: AppColors.blue,
      decoration: TextDecoration.underline,
    ),
    code: TextStyle(
      color: AppColors.text,
      backgroundColor: AppColors.subtle,
      fontFamily: 'monospace',
    ),
    lineHeight: 1.62,
  ),
);

class EditorContextBar extends StatelessWidget {
  const EditorContextBar({
    required this.resultContext,
    required this.activeEssayId,
    required this.onBack,
    required this.onClear,
    super.key,
  });

  final EssayResultContext resultContext;
  final int activeEssayId;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final index = resultContext.resultIds.indexOf(activeEssayId);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
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
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
