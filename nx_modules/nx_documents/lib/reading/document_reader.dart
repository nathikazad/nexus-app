import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nx_documents/documents/document_content.dart';
import 'package:nx_documents/reading/document_table.dart';
import 'package:nx_documents/reading/reading_position.dart';
import 'package:provider/provider.dart';

const nxReaderHighlightYellow = '0x4cffeb3b';
const nxReaderHighlightGreen = '0x4c4caf50';
const nxReaderHighlightPink = '0x4ce91e63';

typedef HeadingLinkActionResolver =
    ({IconData icon, String tooltip})? Function(String href);

class DocumentReader extends StatefulWidget {
  const DocumentReader({
    required this.content,
    required this.onChanged,
    this.onOpenLink,
    this.headingLinkAction,
    this.imageUrlResolver,
    this.textScaleFactor = 1,
    this.onSelectionChanged,
    this.onUseSelection,
    this.initialPosition,
    this.onPositionChanged,
    super.key,
  });

  final DocumentContent content;
  final Future<void> Function(DocumentContent content) onChanged;
  final Future<bool> Function(String href)? onOpenLink;
  final HeadingLinkActionResolver? headingLinkAction;
  final String Function(String url)? imageUrlResolver;
  final double textScaleFactor;
  final ValueChanged<String>? onSelectionChanged;
  final ValueChanged<String>? onUseSelection;
  final ReadingPosition? initialPosition;
  final ValueChanged<ReadingPosition>? onPositionChanged;

  @override
  State<DocumentReader> createState() => _DocumentReaderState();
}

class _DocumentReaderState extends State<DocumentReader> {
  late EditorState _editorState;
  late EditorScrollController _scrollController;
  StreamSubscription<EditorTransactionValue>? _transactions;
  late String _contentFingerprint;
  Timer? _positionTimer;
  ReadingPosition? _lastPosition;
  bool _restoringPosition = true;
  ValueChanged<ReadingPosition>? _positionSink;
  final _linkRecognizers = <String, TapGestureRecognizer>{};
  bool _openingLink = false;

  @override
  void initState() {
    super.initState();
    _createEditor();
  }

  @override
  void didUpdateWidget(covariant DocumentReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fingerprint = _fingerprint(widget.content);
    if (oldWidget.content.identity != widget.content.identity ||
        fingerprint != _contentFingerprint) {
      final position = oldWidget.content.identity == widget.content.identity
          ? _lastPosition
          : null;
      _disposeEditor();
      _createEditor(position: position);
    }
  }

  @override
  void dispose() {
    _disposeEditor();
    super.dispose();
  }

  void _createEditor({ReadingPosition? position}) {
    final initialPosition = position ?? widget.initialPosition;
    _positionSink = widget.onPositionChanged;
    _contentFingerprint = _fingerprint(widget.content);
    _editorState = EditorState(document: _documentFromContent(widget.content));
    _editorState.editable = false;
    _editorState.selectionNotifier.addListener(_selectionChanged);
    _scrollController = EditorScrollController(
      editorState: _editorState,
      shrinkWrap: false,
    );
    final scroll = _scrollController;
    _restoringPosition = true;
    _lastPosition = null;
    scroll.itemPositionsListener.itemPositions.addListener(_positionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(scroll, _scrollController)) return;
      final position = initialPosition;
      final count = _editorState.document.root.children.length;
      if (position != null &&
          count > 0 &&
          scroll.itemScrollController.isAttached) {
        scroll.itemScrollController.jumpTo(
          index: position.index.clamp(0, count - 1),
          alignment: position.alignment,
        );
      }
      _restoringPosition = false;
    });
    _transactions = _editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      if (time == TransactionTime.after &&
          !options.inMemoryUpdate &&
          transaction.operations.isNotEmpty &&
          isHighlightOnlyDocumentTransaction(transaction)) {
        unawaited(_saveHighlight());
      }
    });
  }

  void _disposeEditor() {
    for (final recognizer in _linkRecognizers.values) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
    _positionTimer?.cancel();
    if (_lastPosition case final position?) {
      _positionSink?.call(position);
    }
    _scrollController.itemPositionsListener.itemPositions.removeListener(
      _positionChanged,
    );
    _editorState.selectionNotifier.removeListener(_selectionChanged);
    _transactions?.cancel();
    _scrollController.dispose();
    _editorState.dispose();
  }

  void _positionChanged() {
    if (_restoringPosition) return;
    final visible =
        _scrollController.itemPositionsListener.itemPositions.value
            .where(
              (item) => item.itemTrailingEdge > 0 && item.itemLeadingEdge < 1,
            )
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    if (visible.isEmpty) return;
    final first = visible.first;
    if (first.index >= _editorState.document.root.children.length) return;
    _lastPosition = ReadingPosition(
      index: first.index,
      alignment: first.itemLeadingEdge,
    );
    _positionTimer?.cancel();
    _positionTimer = Timer(const Duration(milliseconds: 200), () {
      if (_lastPosition case final position?) {
        _positionSink?.call(position);
      }
    });
  }

  void _selectionChanged() {
    final selection = _editorState.selection;
    if (selection == null || selection.isCollapsed) return;
    widget.onSelectionChanged?.call(
      _editorState.getTextInSelection(selection).join('\n'),
    );
  }

  Future<void> _saveHighlight() async {
    final jsonDocument = <String, dynamic>{
      ...widget.content.jsonDocument,
      'format': 'appflowy_document',
      'document': _editorState.document.toJson()['document'],
    };
    final content = widget.content.copyWith(jsonDocument: jsonDocument);
    _contentFingerprint = _fingerprint(content);
    await widget.onChanged(content);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyleConfiguration = TextStyleConfiguration(
      text: TextStyle(color: colorScheme.onSurface, fontSize: 18, height: 1.6),
      bold: const TextStyle(fontWeight: FontWeight.w700),
      italic: const TextStyle(fontStyle: FontStyle.italic),
      underline: const TextStyle(decoration: TextDecoration.underline),
      strikethrough: const TextStyle(decoration: TextDecoration.lineThrough),
      href: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      code: TextStyle(
        color: colorScheme.onSurface,
        backgroundColor: colorScheme.surfaceContainerHighest,
        fontFamily: 'monospace',
      ),
      lineHeight: 1.6,
    );
    final style = mobile
        ? EditorStyle.mobile(
            textScaleFactor: widget.textScaleFactor,
            cursorColor: Colors.transparent,
            dragHandleColor: colorScheme.primary,
            selectionColor: colorScheme.primary.withValues(alpha: 0.2),
            padding: EdgeInsets.zero,
            textStyleConfiguration: textStyleConfiguration,
            textSpanDecorator: _readerTextSpanDecorator,
          )
        : EditorStyle.desktop(
            textScaleFactor: widget.textScaleFactor,
            cursorColor: Colors.transparent,
            selectionColor: colorScheme.primary.withValues(alpha: 0.2),
            padding: EdgeInsets.zero,
            textStyleConfiguration: textStyleConfiguration,
            textSpanDecorator: _readerTextSpanDecorator,
          );
    final builders = <String, BlockComponentBuilder>{
      ...standardBlockComponentBuilderMap,
      HeadingBlockKeys.type: HeadingBlockComponentBuilder(
        trailingBuilder: _headingLinkButton,
      ),
      TableBlockKeys.type: NxReadTableBlockComponentBuilder(),
      if (widget.imageUrlResolver != null)
        ImageBlockKeys.type: _ResolvedImageBlockComponentBuilder(
          resolveUrl: widget.imageUrlResolver!,
        ),
    };
    final editor = AppFlowyEditor(
      editable: false,
      disableKeyboardService: true,
      editorState: _editorState,
      editorScrollController: _scrollController,
      editorStyle: style,
      blockComponentBuilders: builders,
      characterShortcutEvents: const <CharacterShortcutEvent>[],
      commandShortcutEvents: const <CommandShortcutEvent>[],
      footer: const SizedBox(height: 24),
    );
    return ReaderHighlightToolbar(
      editorState: _editorState,
      editorScrollController: _scrollController,
      onUseSelection: widget.onUseSelection,
      child: editor,
    );
  }

  TextSpan _readerTextSpanDecorator(
    BuildContext context,
    Node node,
    int index,
    TextInsert text,
    TextSpan before,
    TextSpan after,
  ) {
    final href = text.attributes?[AppFlowyRichTextKeys.href] as String?;
    if (href == null || href.trim().isEmpty) return before;
    if (node.type == HeadingBlockKeys.type &&
        widget.headingLinkAction?.call(href) != null) {
      return TextSpan(
        text: text.text,
        style: before.style?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          decoration: TextDecoration.none,
        ),
      );
    }
    return TextSpan(
      text: text.text,
      style: before.style,
      mouseCursor: SystemMouseCursors.click,
      recognizer: _linkRecognizers.putIfAbsent(
        '${node.id}:$index:$href',
        () => TapGestureRecognizer()..onTap = () => unawaited(_openLink(href)),
      ),
    );
  }

  Widget? _headingLinkButton(BuildContext context, Node node) {
    for (final insert
        in node.delta?.whereType<TextInsert>() ?? <TextInsert>[]) {
      final href = insert.attributes?[AppFlowyRichTextKeys.href];
      if (href is! String) continue;
      final action = widget.headingLinkAction?.call(href);
      if (action == null) continue;
      return IconButton(
        tooltip: action.tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(action.icon, size: 22),
        onPressed: () => unawaited(_openLink(href)),
      );
    }
    return null;
  }

  Future<void> _openLink(String href) async {
    // Keep one activation in flight, including while its destination is open.
    // Repeated clicks must not queue duplicate reader routes during file loading.
    if (_openingLink || !mounted) return;
    _openingLink = true;
    try {
      final handled = await widget.onOpenLink?.call(href) ?? false;
      if (!handled && mounted) await editorLaunchUrl(href);
    } finally {
      _openingLink = false;
    }
  }
}

Document _documentFromContent(DocumentContent content) {
  if (content.jsonDocument['format'] == 'appflowy_document') {
    final documentJson = content.jsonDocument['document'];
    if (documentJson is Map) {
      return Document.fromJson(<String, dynamic>{
        'document': Map<String, dynamic>.from(documentJson),
      });
    }
  }
  if (content.plainText.trim().isNotEmpty) {
    return markdownToDocument(content.plainText);
  }
  return Document.blank(withInitialText: true);
}

String _fingerprint(DocumentContent content) {
  return '${content.identity.modelType}:${content.identity.id}:'
      '${jsonEncode(content.jsonDocument)}';
}

bool isHighlightOnlyDocumentTransaction(Transaction transaction) {
  return transaction.operations.every(_operationOnlyChangesHighlight);
}

bool _operationOnlyChangesHighlight(Operation operation) {
  if (operation is! UpdateOperation ||
      operation.attributes.length != 1 ||
      !operation.attributes.containsKey(blockComponentDelta)) {
    return false;
  }
  final beforeJson = operation.oldAttributes[blockComponentDelta];
  final afterJson = operation.attributes[blockComponentDelta];
  if (beforeJson is! List || afterJson is! List) return false;
  final before = _canonicalTextRuns(
    Delta.fromJson(beforeJson),
    removeHighlight: true,
  );
  final after = _canonicalTextRuns(
    Delta.fromJson(afterJson),
    removeHighlight: true,
  );
  if (before == null || after == null || !_sameTextRuns(before, after)) {
    return false;
  }
  final beforeWithHighlight = _canonicalTextRuns(Delta.fromJson(beforeJson));
  final afterWithHighlight = _canonicalTextRuns(Delta.fromJson(afterJson));
  return beforeWithHighlight != null &&
      afterWithHighlight != null &&
      !_sameTextRuns(beforeWithHighlight, afterWithHighlight);
}

List<({String text, Attributes attributes})>? _canonicalTextRuns(
  Delta delta, {
  bool removeHighlight = false,
}) {
  final runs = <({String text, Attributes attributes})>[];
  for (final operation in delta) {
    if (operation is! TextInsert) return null;
    final attributes = <String, dynamic>{...?operation.attributes};
    if (removeHighlight) {
      attributes.remove(AppFlowyRichTextKeys.backgroundColor);
    }
    if (runs.isNotEmpty && mapEquals(runs.last.attributes, attributes)) {
      final previous = runs.removeLast();
      runs.add((text: previous.text + operation.text, attributes: attributes));
    } else {
      runs.add((text: operation.text, attributes: attributes));
    }
  }
  return runs;
}

bool _sameTextRuns(
  List<({String text, Attributes attributes})> left,
  List<({String text, Attributes attributes})> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].text != right[index].text ||
        !mapEquals(left[index].attributes, right[index].attributes)) {
      return false;
    }
  }
  return true;
}

class ReaderHighlightToolbar extends StatefulWidget {
  const ReaderHighlightToolbar({
    required this.editorState,
    required this.editorScrollController,
    required this.child,
    this.onUseSelection,
    super.key,
  });

  final EditorState editorState;
  final EditorScrollController editorScrollController;
  final Widget child;
  final ValueChanged<String>? onUseSelection;

  @override
  State<ReaderHighlightToolbar> createState() => _ReaderHighlightToolbarState();
}

class _ReaderHighlightToolbarState extends State<ReaderHighlightToolbar> {
  static const _toolbarHeight = 42.0;
  static const _highlightToolbarWidth = 152.0;
  OverlayEntry? _overlayEntry;
  Selection? _selection;
  Timer? _showTimer;

  @override
  void initState() {
    super.initState();
    widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.addListener(_hide);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hide();
    widget.editorState.selectionNotifier.removeListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.removeListener(_hide);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onSelectionChanged() {
    final selection = widget.editorState.selection;
    if (selection == null ||
        selection.isCollapsed ||
        widget.editorState.selectionType == SelectionType.block ||
        !widget.editorState.getNodesInSelection(selection).any((node) {
          final delta = node.delta;
          return delta != null && delta.isNotEmpty;
        })) {
      _hide();
      return;
    }
    _selection = selection.normalized;
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 80), _show);
  }

  void _show() {
    final selection = _selection;
    if (selection == null || !mounted) return;
    final rects = widget.editorState.selectionRects();
    if (rects.isEmpty) return;
    final rect = rects.reduce((a, b) => a.top <= b.top ? a : b);
    final width = MediaQuery.sizeOf(context).width;
    final toolbarWidth = widget.onUseSelection == null
        ? _highlightToolbarWidth
        : _highlightToolbarWidth + 40;
    final left = (rect.center.dx - toolbarWidth / 2).clamp(
      8.0,
      width - toolbarWidth - 8,
    );
    final top = rect.top - _toolbarHeight - 8;
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top < 8 ? rect.bottom + 8 : top,
        child: _HighlightToolbarSurface(
          editorState: widget.editorState,
          selection: selection,
          onUseSelection: widget.onUseSelection,
          onClose: _hide,
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _hide() {
    _showTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _HighlightToolbarSurface extends StatelessWidget {
  const _HighlightToolbarSurface({
    required this.editorState,
    required this.selection,
    required this.onClose,
    this.onUseSelection,
  });

  final EditorState editorState;
  final Selection selection;
  final VoidCallback onClose;
  final ValueChanged<String>? onUseSelection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.inverseSurface,
      borderRadius: BorderRadius.circular(6),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onUseSelection != null)
              Tooltip(
                message: 'Ask AI about selection',
                preferBelow: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _useWithAi(),
                  child: SizedBox(
                    key: const ValueKey<String>('reader-use-selection'),
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Icon(
                        Icons.auto_awesome_outlined,
                        size: 19,
                        color: colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            _button(
              key: const ValueKey<String>('reader-highlight-clear'),
              tooltip: 'Remove highlight',
              child: Icon(
                Icons.format_color_reset_rounded,
                size: 19,
                color: colorScheme.onInverseSurface,
              ),
              colorHex: null,
            ),
            _swatch('Yellow', nxReaderHighlightYellow),
            _swatch('Green', nxReaderHighlightGreen),
            _swatch('Pink', nxReaderHighlightPink),
          ],
        ),
      ),
    );
  }

  Widget _swatch(String name, String colorHex) {
    return _button(
      key: ValueKey<String>('reader-highlight-$colorHex'),
      tooltip: name,
      colorHex: colorHex,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: colorHex.tryToColor(),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1),
        ),
      ),
    );
  }

  Widget _button({
    required Key key,
    required String tooltip,
    required Widget child,
    required String? colorHex,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apply(colorHex),
        child: SizedBox(
          key: key,
          width: 36,
          height: 36,
          child: Center(child: child),
        ),
      ),
    );
  }

  void _apply(String? colorHex) {
    unawaited(_applyHighlight(editorState, selection, colorHex));
    onClose();
  }

  void _useWithAi() {
    final text = editorState.getTextInSelection(selection).join('\n').trim();
    if (text.isNotEmpty) onUseSelection?.call(text);
    onClose();
  }
}

Future<void> _applyHighlight(
  EditorState editorState,
  Selection selection,
  String? colorHex,
) async {
  final wasEditable = editorState.editable;
  editorState.editable = true;
  try {
    await editorState.formatDelta(selection, <String, dynamic>{
      AppFlowyRichTextKeys.backgroundColor: colorHex,
    }, withUpdateSelection: true);
    await editorState.updateSelectionWithReason(null);
  } finally {
    editorState.editable = wasEditable;
  }
}

class _ResolvedImageBlockComponentBuilder extends BlockComponentBuilder {
  _ResolvedImageBlockComponentBuilder({required this.resolveUrl});

  final String Function(String url) resolveUrl;

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return _ResolvedImageBlockComponentWidget(
      key: context.node.key,
      node: context.node,
      configuration: configuration,
      resolveUrl: resolveUrl,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

class _ResolvedImageBlockComponentWidget extends BlockComponentStatefulWidget {
  const _ResolvedImageBlockComponentWidget({
    required super.node,
    required this.resolveUrl,
    super.key,
    super.configuration = const BlockComponentConfiguration(),
  });

  final String Function(String url) resolveUrl;

  @override
  State<_ResolvedImageBlockComponentWidget> createState() =>
      _ResolvedImageBlockComponentWidgetState();
}

class _ResolvedImageBlockComponentWidgetState
    extends State<_ResolvedImageBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  final _imageKey = GlobalKey();

  late final EditorState editorState = Provider.of<EditorState>(
    context,
    listen: false,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Widget build(BuildContext context) {
    final attributes = node.attributes;
    final rawUrl = attributes[ImageBlockKeys.url]?.toString() ?? '';
    final alignment = AlignmentExtension.fromString(
      attributes[ImageBlockKeys.align] ?? 'center',
    );
    final width =
        (attributes[ImageBlockKeys.width] as num?)?.toDouble() ??
        MediaQuery.sizeOf(context).width;
    final height = (attributes[ImageBlockKeys.height] as num?)?.toDouble();
    final image = Padding(
      key: _imageKey,
      padding: padding,
      child: ResizableImage(
        src: widget.resolveUrl(rawUrl),
        width: width,
        height: height,
        editable: false,
        alignment: alignment,
        onResize: (_) {},
      ),
    );
    return BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const <BlockSelectionType>[BlockSelectionType.block],
      child: image,
    );
  }

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  Position start() => Position(path: node.path, offset: 0);

  @override
  Position end() => Position(path: node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset offset) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final imageBox = _imageKey.currentContext?.findRenderObject();
    return imageBox is RenderBox ? Offset.zero & imageBox.size : Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final box = _renderBox;
    if (box == null) return null;
    return Rect.fromLTWH(
      -box.size.width / 2,
      0,
      box.size.width,
      box.size.height,
    );
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = _renderBox;
    final imageBox = _imageKey.currentContext?.findRenderObject();
    if (parentBox != null && imageBox is RenderBox) {
      return <Rect>[
        imageBox.localToGlobal(Offset.zero, ancestor: parentBox) &
            imageBox.size,
      ];
    }
    return parentBox == null
        ? const <Rect>[]
        : <Rect>[Offset.zero & parentBox.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) {
    return Selection.single(path: node.path, startOffset: 0, endOffset: 1);
  }

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    return _renderBox!.localToGlobal(offset);
  }
}
