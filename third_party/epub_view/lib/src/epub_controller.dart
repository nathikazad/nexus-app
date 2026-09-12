part of 'ui/epub_view.dart';

class EpubController {
  EpubController({required this.document, this.epubCfi, this.initialLocation});

  final EpubLocation? initialLocation;
  final locationListenable = ValueNotifier<EpubLocation?>(null);

  Future<EpubBook> document;
  final String? epubCfi;

  _EpubViewState? _epubViewState;
  List<EpubViewChapter>? _cacheTableOfContents;
  EpubBook? _document;
  bool _disposed = false;

  EpubChapterViewValue? get currentValue => _epubViewState?._currentValue;

  final isBookLoaded = ValueNotifier<bool>(false);
  final ValueNotifier<EpubViewLoadingState> loadingState = ValueNotifier(
    EpubViewLoadingState.loading,
  );

  final currentValueListenable = ValueNotifier<EpubChapterViewValue?>(null);

  final tableOfContentsListenable = ValueNotifier<List<EpubViewChapter>>([]);
  final pageListenable = ValueNotifier<EpubPageInfo?>(null);

  void nextPage() => _epubViewState?._pagedKey.currentState?.next();
  void previousPage() => _epubViewState?._pagedKey.currentState?.previous();

  void jumpTo({required int index, double alignment = 0}) =>
      _epubViewState?._jumpTo(index, alignment: alignment);

  Future<void>? scrollTo({
    required int index,
    Duration duration = const Duration(milliseconds: 250),
    double alignment = 0,
    Curve curve = Curves.linear,
  }) {
    if (_epubViewState?.widget.paginated == true) {
      jumpTo(index: index);
      return Future.value();
    }
    return _epubViewState?._itemScrollController?.scrollTo(
        index: index, duration: duration, alignment: alignment, curve: curve);
  }

  void gotoEpubCfi(
    String epubCfi, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) {
    _epubViewState?._gotoEpubCfi(
      epubCfi,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
  }

  String? generateEpubCfi() => _epubViewState?._epubCfiReader?.generateCfi(
        book: _document,
        chapter: _epubViewState?._currentValue?.chapter,
        paragraphIndex: _epubViewState?._getAbsParagraphIndexBy(
          positionIndex: _epubViewState?._currentValue?.position.index ?? 0,
          trailingEdge:
              _epubViewState?._currentValue?.position.itemTrailingEdge,
          leadingEdge: _epubViewState?._currentValue?.position.itemLeadingEdge,
        ),
      );

  List<EpubViewChapter> tableOfContents() {
    if (_cacheTableOfContents != null) {
      return _cacheTableOfContents ?? [];
    }

    if (_document == null) {
      return [];
    }

    int index = -1;

    return _cacheTableOfContents =
        _document!.Chapters!.fold<List<EpubViewChapter>>([], (acc, next) {
      index += 1;
      acc.add(EpubViewChapter(next.Title, _getChapterStartIndex(index)));
      for (final subChapter in next.SubChapters!) {
        index += 1;
        acc.add(
          EpubViewSubChapter(
            subChapter.Title,
            _getChapterStartIndex(index),
          ),
        );
      }
      return acc;
    });
  }

  Future<void> loadDocument(Future<EpubBook> document) {
    this.document = document;
    return _loadDocument(document);
  }

  void dispose() {
    _disposed = true;
    _epubViewState = null;
    _document = null;
    _cacheTableOfContents = null;
    isBookLoaded.dispose();
    loadingState.dispose();
    currentValueListenable.dispose();
    tableOfContentsListenable.dispose();
    pageListenable.dispose();
    locationListenable.dispose();
  }

  Future<void> _loadDocument(Future<EpubBook> document) async {
    isBookLoaded.value = false;
    try {
      loadingState.value = EpubViewLoadingState.loading;
      final loaded = await document;
      if (_disposed || _epubViewState == null) return;
      _document = loaded;
      await _epubViewState!._init();
      if (_disposed || _epubViewState == null) return;
      tableOfContentsListenable.value = tableOfContents();
      loadingState.value = EpubViewLoadingState.success;
    } catch (error) {
      if (_disposed || _epubViewState == null) return;
      _epubViewState!._loadingError = error is Exception
          ? error
          : Exception('An unexpected error occurred');
      loadingState.value = EpubViewLoadingState.error;
    }
  }

  int _getChapterStartIndex(int index) =>
      index < _epubViewState!._chapterIndexes.length
          ? _epubViewState!._chapterIndexes[index]
          : 0;

  void _attach(_EpubViewState epubReaderViewState) {
    _epubViewState = epubReaderViewState;

    _loadDocument(document);
  }

  void _detach() {
    _epubViewState = null;
  }
}
