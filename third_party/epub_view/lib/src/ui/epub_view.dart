import 'dart:async';
import 'dart:typed_data';

import 'package:epub_view/src/data/link_target.dart';
import 'package:epub_view/src/data/epub_cfi_reader.dart';
import 'package:epub_view/src/data/epub_parser.dart';
import 'package:epub_view/src/data/models/chapter.dart';
import 'package:epub_view/src/data/models/chapter_view_value.dart';
import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'paged_content.dart';

export 'package:epubx/epubx.dart' hide Image;

part '../epub_controller.dart';
part '../helpers/epub_view_builders.dart';

const _minTrailingEdge = 0.55;
const _minLeadingEdge = -0.05;

typedef ExternalLinkPressed = void Function(String href);

class EpubView extends StatefulWidget {
  const EpubView({
    required this.controller,
    this.onExternalLinkPressed,
    this.onChapterChanged,
    this.onDocumentLoaded,
    this.onDocumentError,
    this.builders = const EpubViewBuilders<DefaultBuilderOptions>(
      options: DefaultBuilderOptions(),
    ),
    this.shrinkWrap = false,
    this.paginated = false,
    super.key,
  });

  final EpubController controller;
  final ExternalLinkPressed? onExternalLinkPressed;
  final bool shrinkWrap;
  final bool paginated;
  final void Function(EpubChapterViewValue? value)? onChapterChanged;

  /// Called when a document is loaded
  final void Function(EpubBook document)? onDocumentLoaded;

  /// Called when a document loading error
  final void Function(Exception? error)? onDocumentError;

  /// Builders
  final EpubViewBuilders builders;

  @override
  State<EpubView> createState() => _EpubViewState();
}

class _EpubViewState extends State<EpubView> {
  Exception? _loadingError;
  ItemScrollController? _itemScrollController;
  ItemPositionsListener? _itemPositionListener;
  List<EpubChapter> _chapters = [];
  List<Paragraph> _paragraphs = [];
  EpubCfiReader? _epubCfiReader;
  EpubChapterViewValue? _currentValue;
  final _chapterIndexes = <int>[];
  final _imageProviders = <ImageProvider>{};
  final _pagedKey = GlobalKey<PagedEpubContentState>();

  EpubController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _itemScrollController = ItemScrollController();
    _itemPositionListener = ItemPositionsListener.create();
    _controller._attach(this);
    _controller.loadingState.addListener(_onLoadingChanged);
  }

  void _onLoadingChanged() {
    if (!mounted) return;
    switch (_controller.loadingState.value) {
      case EpubViewLoadingState.loading:
        break;
      case EpubViewLoadingState.success:
        widget.onDocumentLoaded?.call(_controller._document!);
        break;
      case EpubViewLoadingState.error:
        widget.onDocumentError?.call(_loadingError);
        break;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _releaseImages() {
    for (final provider in _imageProviders) {
      unawaited(provider.evict());
    }
    _imageProviders.clear();
  }

  @override
  void dispose() {
    _releaseImages();
    _controller.loadingState.removeListener(_onLoadingChanged);
    _itemPositionListener!.itemPositions.removeListener(_changeListener);
    _controller._detach();
    super.dispose();
  }

  Future<bool> _init() async {
    if (_controller.isBookLoaded.value) {
      return true;
    }
    _chapters = parseChapters(_controller._document!);
    final parseParagraphsResult = parseParagraphs(
      _chapters,
      _controller._document!.Content,
    );
    _paragraphs = parseParagraphsResult.flatParagraphs;
    _chapterIndexes.addAll(parseParagraphsResult.chapterIndexes);

    _epubCfiReader = EpubCfiReader.parser(
      cfiInput: _controller.epubCfi,
      chapters: _chapters,
      paragraphs: _paragraphs,
    );
    _itemPositionListener!.itemPositions.addListener(_changeListener);
    _controller.isBookLoaded.value = true;

    return true;
  }

  void _changeListener() {
    if (_paragraphs.isEmpty ||
        _itemPositionListener!.itemPositions.value.isEmpty) {
      return;
    }
    final position = _itemPositionListener!.itemPositions.value.first;
    final chapterIndex = _getChapterIndexBy(
      positionIndex: position.index,
      trailingEdge: position.itemTrailingEdge,
      leadingEdge: position.itemLeadingEdge,
    );
    final paragraphIndex = _getParagraphIndexBy(
      positionIndex: position.index,
      trailingEdge: position.itemTrailingEdge,
      leadingEdge: position.itemLeadingEdge,
    );
    _currentValue = EpubChapterViewValue(
      chapter: chapterIndex >= 0 ? _chapters[chapterIndex] : null,
      chapterNumber: chapterIndex + 1,
      paragraphNumber: paragraphIndex + 1,
      position: position,
    );
    _controller.currentValueListenable.value = _currentValue;
    widget.onChapterChanged?.call(_currentValue);
  }

  void _pagedPosition(int index) {
    if (_chapterIndexes.isEmpty) return;
    final chapterIndex = _getChapterIndexBy(positionIndex: index);
    _currentValue = EpubChapterViewValue(
      chapter: chapterIndex >= 0 ? _chapters[chapterIndex] : null,
      chapterNumber: chapterIndex + 1,
      paragraphNumber: _getParagraphIndexBy(positionIndex: index) + 1,
      position:
          ItemPosition(index: index, itemLeadingEdge: 0, itemTrailingEdge: 1),
    );
    _controller.currentValueListenable.value = _currentValue;
    widget.onChapterChanged?.call(_currentValue);
  }

  void _jumpTo(int index, {double alignment = 0}) {
    if (widget.paginated) {
      _pagedKey.currentState?.jumpTo(index);
    } else {
      _itemScrollController?.jumpTo(index: index, alignment: alignment);
    }
  }

  void _gotoEpubCfi(
    String? epubCfi, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) {
    _epubCfiReader?.epubCfi = epubCfi;
    final index = _epubCfiReader?.paragraphIndexByCfiFragment;

    if (index == null) {
      return;
    }

    if (widget.paginated) {
      _jumpTo(index);
      return;
    }

    _itemScrollController?.scrollTo(
      index: index,
      duration: duration,
      alignment: alignment,
      curve: curve,
    );
  }

  void _onLinkPressed(String href, int sourceIndex) {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (uri.hasScheme || uri.hasAuthority) {
      widget.onExternalLinkPressed?.call(href);
      return;
    }
    final target = resolveLinkTarget(
      href: href,
      sourceIndex: sourceIndex,
      chapters: _chapters,
      paragraphs: _paragraphs,
    );
    if (target != null) _jumpTo(target);
  }

  int _getChapterIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    final posIndex = _getAbsParagraphIndexBy(
      positionIndex: positionIndex,
      trailingEdge: trailingEdge,
      leadingEdge: leadingEdge,
    );
    final index = posIndex >= _chapterIndexes.last
        ? _chapterIndexes.length
        : _chapterIndexes.indexWhere((chapterIndex) {
            if (posIndex < chapterIndex) {
              return true;
            }
            return false;
          });

    return index - 1;
  }

  int _getParagraphIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    final posIndex = _getAbsParagraphIndexBy(
      positionIndex: positionIndex,
      trailingEdge: trailingEdge,
      leadingEdge: leadingEdge,
    );

    final index = _getChapterIndexBy(positionIndex: posIndex);

    if (index == -1) {
      return posIndex;
    }

    return posIndex - _chapterIndexes[index];
  }

  int _getAbsParagraphIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    int posIndex = positionIndex;
    if (trailingEdge != null &&
        leadingEdge != null &&
        trailingEdge < _minTrailingEdge &&
        leadingEdge < _minLeadingEdge) {
      posIndex += 1;
    }

    return posIndex;
  }

  static Widget _chapterDividerBuilder(EpubChapter chapter) => Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Color(0x24000000)),
        alignment: Alignment.centerLeft,
        child: Text(
          chapter.Title ?? '',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      );

  static Widget _chapterBuilder(
    BuildContext context,
    EpubViewBuilders builders,
    EpubBook document,
    List<EpubChapter> chapters,
    List<Paragraph> paragraphs,
    int index,
    int chapterIndex,
    int paragraphIndex,
    ExternalLinkPressed onExternalLinkPressed,
  ) {
    if (paragraphs.isEmpty) {
      return Container();
    }

    final defaultBuilder = builders as EpubViewBuilders<DefaultBuilderOptions>;
    final options = defaultBuilder.options;

    return Column(
      children: <Widget>[
        if (chapterIndex >= 0 &&
            paragraphIndex == 0 &&
            context.findAncestorStateOfType<PagedEpubContentState>() == null)
          builders.chapterDividerBuilder(chapters[chapterIndex]),
        Html(
          data: paragraphs[index].element.outerHtml,
          onLinkTap: (href, _, __) => onExternalLinkPressed(href!),
          style: {
            'html': Style(
              padding: HtmlPaddings.only(
                top: (options.paragraphPadding as EdgeInsets?)?.top,
                right: (options.paragraphPadding as EdgeInsets?)?.right,
                bottom: (options.paragraphPadding as EdgeInsets?)?.bottom,
                left: (options.paragraphPadding as EdgeInsets?)?.left,
              ),
            ).merge(Style.fromTextStyle(options.textStyle)),
          },
          extensions: [
            TagExtension(
              tagsToExtend: {"img"},
              builder: (imageContext) {
                final source = imageContext.attributes['src'];
                if (source == null) return const SizedBox.shrink();
                final url = Uri.decodeFull(source).replaceAll('../', '');
                final bytes = document.Content?.Images?[url]?.Content;
                if (bytes == null) return const SizedBox.shrink();
                final content =
                    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
                final provider = ResizeImage.resizeIfNeeded(
                    1200, null, MemoryImage(content));
                context
                    .findAncestorStateOfType<_EpubViewState>()
                    ?._imageProviders
                    .add(provider);
                final page =
                    context.findAncestorStateOfType<PagedEpubContentState>();
                return ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: page == null
                          ? double.infinity
                          : (page.viewport.height - 24)
                              .clamp(1.0, double.infinity)),
                  child: Image(
                    image: provider,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('Image could not be displayed'),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context) {
    if (widget.paginated) {
      return PagedEpubContent(
        key: _pagedKey,
        blockCount: _paragraphs.length,
        chapterStarts: _chapterIndexes,
        initialBlock: _epubCfiReader!.paragraphIndexByCfiFragment ?? 0,
        initialLocation: _controller.initialLocation,
        onLocation: (location) =>
            _controller.locationListenable.value = location,
        revision: (widget.builders.options as DefaultBuilderOptions).textStyle,
        headingBlocks: {
          for (var i = 0; i < _paragraphs.length; i++)
            if (RegExp(r'^h[1-6]$')
                .hasMatch(_paragraphs[i].element.localName ?? ''))
              i
        },
        onPosition: _pagedPosition,
        onPage: (page) => _controller.pageListenable.value = page,
        onChapterChanged: _releaseImages,
        blockBuilder: (context, index) => widget.builders.chapterBuilder(
          context,
          widget.builders,
          widget.controller._document!,
          _chapters,
          _paragraphs,
          index,
          _getChapterIndexBy(positionIndex: index),
          _getParagraphIndexBy(positionIndex: index),
          (href) => _onLinkPressed(href, index),
        ),
      );
    }
    return ScrollablePositionedList.builder(
      shrinkWrap: widget.shrinkWrap,
      initialScrollIndex: _epubCfiReader!.paragraphIndexByCfiFragment ?? 0,
      itemCount: _paragraphs.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionListener,
      itemBuilder: (BuildContext context, int index) {
        return widget.builders.chapterBuilder(
          context,
          widget.builders,
          widget.controller._document!,
          _chapters,
          _paragraphs,
          index,
          _getChapterIndexBy(positionIndex: index),
          _getParagraphIndexBy(positionIndex: index),
          (href) => _onLinkPressed(href, index),
        );
      },
    );
  }

  static Widget _builder(
    BuildContext context,
    EpubViewBuilders builders,
    EpubViewLoadingState state,
    WidgetBuilder loadedBuilder,
    Exception? loadingError,
  ) {
    final Widget content = () {
      switch (state) {
        case EpubViewLoadingState.loading:
          return KeyedSubtree(
            key: const Key('epubx.root.loading'),
            child: builders.loaderBuilder?.call(context) ?? const SizedBox(),
          );
        case EpubViewLoadingState.error:
          return KeyedSubtree(
            key: const Key('epubx.root.error'),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: builders.errorBuilder?.call(context, loadingError!) ??
                  Center(child: Text(loadingError.toString())),
            ),
          );
        case EpubViewLoadingState.success:
          return KeyedSubtree(
            key: const Key('epubx.root.success'),
            child: loadedBuilder(context),
          );
      }
    }();

    final defaultBuilder = builders as EpubViewBuilders<DefaultBuilderOptions>;
    final options = defaultBuilder.options;

    return AnimatedSwitcher(
      duration: options.loaderSwitchDuration,
      transitionBuilder: options.transitionBuilder,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builders.builder(
      context,
      widget.builders,
      _controller.loadingState.value,
      _buildLoaded,
      _loadingError,
    );
  }
}
