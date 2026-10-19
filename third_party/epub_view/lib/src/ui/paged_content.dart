import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'page_breaks.dart';
import 'epub_highlight.dart';

class EpubPageInfo {
  const EpubPageInfo(this.page, this.pages, this.atStart, this.atEnd);
  final int page;
  final int pages;
  final bool atStart;
  final bool atEnd;
}

/// A bounded text window in the currently rendered chapter. No book upload.
String epubReadingWindow(String text, int character,
    {int before = 100, int after = 400}) {
  final words = RegExp(r'\S+').allMatches(text).toList();
  if (words.isEmpty) return '';
  var current = words.indexWhere((word) => word.end > character);
  if (current < 0) current = words.length - 1;
  final start = math.max(0, current - math.max(0, before)).toInt();
  final end = math.min(words.length, current + math.max(1, after)).toInt();
  final anchor = words[current].start;
  // Also bound unusually long words/passages to the companion wire budget.
  final left = math.max(words[start].start, anchor - 1200);
  final right = math.min(words[end - 1].end, anchor + 4500);
  return '${text.substring(left, anchor)}\n[Current reading position]\n${text.substring(anchor, right)}';
}

/// A source position within the existing HTML renderer, independent of pixels.
class EpubLocation {
  const EpubLocation(this.block, [this.run = 0, this.character = 0]);
  final int block;
  final int run;
  final int character;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'block': block,
        'run': run,
        'character': character,
      };

  static EpubLocation? fromJson(dynamic json) {
    if (json is! Map || json['version'] != 1) return null;
    final values = [json['block'], json['run'], json['character']];
    if (values.any((value) => value is! int || value < 0)) return null;
    return EpubLocation(values[0] as int, values[1] as int, values[2] as int);
  }
}

class _Run {
  _Run(this.block, this.index, this.render, this.offset);
  final int block;
  final int index;
  final RenderParagraph render;
  final Offset offset;
}

// flutter_html nests block widgets inside WidgetSpans. Those placeholder
// rectangles are NOT indivisible text lines: their descendants are measured
// separately, otherwise a complete nested chapter could look like one line.
List<TextSelection> _textSelections(InlineSpan span) {
  var offset = 0;
  final result = <TextSelection>[];
  void visit(InlineSpan node) {
    if (node is PlaceholderSpan) {
      offset++;
      return;
    }
    if (node is TextSpan) {
      final text = node.text ?? '';
      if (text.trim().isNotEmpty) {
        result.add(TextSelection(
            baseOffset: offset, extentOffset: offset + text.length));
      }
      offset += text.length;
      for (final child in node.children ?? const <InlineSpan>[]) {
        visit(child);
      }
    }
  }

  visit(span);
  return result;
}

/// Keeps only one chapter's widget tree mounted. Pages share that layout;
/// clipping uses measured line boundaries, not arbitrary viewport increments.
class PagedEpubContent extends StatefulWidget {
  const PagedEpubContent({
    required this.blockCount,
    required this.chapterStarts,
    required this.blockBuilder,
    required this.revision,
    required this.onPosition,
    required this.onPage,
    this.onChapterChanged,
    this.initialBlock = 0,
    this.initialLocation,
    this.onLocation,
    this.headingBlocks = const {},
    this.onBookPage,
    this.onMeasured,
    this.measureOnly = false,
    this.highlights = const [],
    this.onHighlightChanged,
    super.key,
  });
  final int blockCount;
  final List<int> chapterStarts;
  final Widget Function(BuildContext, int) blockBuilder;
  final Object revision;
  final int initialBlock;
  final EpubLocation? initialLocation;
  final ValueChanged<EpubLocation>? onLocation;
  final Set<int> headingBlocks;
  final ValueChanged<int> onPosition;
  final ValueChanged<EpubPageInfo> onPage;
  final VoidCallback? onChapterChanged;
  final ValueChanged<EpubPageInfo?>? onBookPage;
  final ValueChanged<int>? onMeasured;
  final bool measureOnly;
  final List<EpubHighlight> highlights;
  final void Function(EpubHighlight highlight, bool deleted)?
      onHighlightChanged;

  @override
  State<PagedEpubContent> createState() => PagedEpubContentState();
}

class PagedEpubContentState extends State<PagedEpubContent> {
  EpubHighlight? _selection;
  EpubLocation? _selectionOrigin;
  final _viewportKey = GlobalKey();

  double get _pageStart => _breaks.isEmpty ? 0 : _breaks[_page];

  (_Run, int)? _textAt(Offset global) {
    final box = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return null;
    final point = box.globalToLocal(global) + Offset(0, _pageStart);
    for (final run in _runs.reversed) {
      final local = point - run.offset;
      if (!(Offset.zero & run.render.size).contains(local)) continue;
      final index = run.render.getPositionForOffset(local).offset;
      if (_textSelections(run.render.text)
          .any((s) => index >= s.start && index <= s.end)) {
        return (run, index);
      }
    }
    return null;
  }

  List<Rect> _highlightRects(EpubHighlight highlight) {
    final result = <Rect>[];
    for (final run in _runs) {
      final start = EpubLocation(run.block, run.index);
      final end = EpubLocation(
          run.block, run.index, run.render.text.toPlainText().length);
      if (compareEpubLocations(end, highlight.start) <= 0 ||
          compareEpubLocations(start, highlight.end) >= 0) continue;
      final from = compareEpubLocations(start, highlight.start) < 0
          ? highlight.start.character
          : 0;
      final to = compareEpubLocations(end, highlight.end) > 0
          ? highlight.end.character
          : end.character;
      for (final range in _textSelections(run.render.text)) {
        final a = math.max(from, range.start), b = math.min(to, range.end);
        if (a >= b) continue;
        for (final rect in run.render.getBoxesForSelection(
            TextSelection(baseOffset: a, extentOffset: b))) {
          result.add(rect.toRect().shift(run.offset - Offset(0, _pageStart)));
        }
      }
    }
    return result;
  }

  String _selectedText(EpubLocation start, EpubLocation end) {
    final text = <String>[];
    for (final run in _runs) {
      final a = EpubLocation(run.block, run.index);
      final plain = run.render.text.toPlainText();
      final b = EpubLocation(run.block, run.index, plain.length);
      if (compareEpubLocations(b, start) <= 0 ||
          compareEpubLocations(a, end) >= 0) continue;
      final from = compareEpubLocations(a, start) < 0 ? start.character : 0;
      final to =
          compareEpubLocations(b, end) > 0 ? end.character : plain.length;
      text.add(plain.substring(from, to).replaceAll('\uFFFC', ''));
    }
    return text.join('\n');
  }

  void _startSelection(Offset global) {
    final hit = _textAt(global);
    if (hit == null) return;
    final (run, index) = hit;
    final word = run.render.getWordBoundary(TextPosition(offset: index));
    final start = EpubLocation(run.block, run.index, word.start);
    final end = EpubLocation(run.block, run.index, word.end);
    setState(() {
      _selectionOrigin = start;
      _selection = EpubHighlight(
          id: '', start: start, end: end, text: _selectedText(start, end));
    });
  }

  void _extendSelection(Offset global) {
    final hit = _textAt(global);
    final origin = _selectionOrigin;
    if (hit == null || origin == null) return;
    final (run, index) = hit;
    final word = run.render.getWordBoundary(TextPosition(offset: index));
    final point = EpubLocation(run.block, run.index, word.end);
    final backwards = compareEpubLocations(point, origin) < 0;
    final start =
        backwards ? EpubLocation(run.block, run.index, word.start) : origin;
    final end = backwards ? origin : point;
    setState(() => _selection = EpubHighlight(
        id: '', start: start, end: end, text: _selectedText(start, end)));
  }

  void _tapHighlight(Offset local) {
    for (final highlight in widget.highlights.reversed) {
      if (_highlightRects(highlight).any((rect) => rect.contains(local))) {
        setState(() => _selection = highlight);
        return;
      }
    }
    setState(() => _selection = null);
  }

  void _applyHighlight(int color, {bool deleted = false}) {
    final selection = _selection;
    if (selection == null ||
        compareEpubLocations(selection.start, selection.end) >= 0) return;
    widget.onHighlightChanged?.call(
        EpubHighlight(
            id: selection.id,
            start: selection.start,
            end: selection.end,
            text: selection.text,
            color: color),
        deleted);
    setState(() {
      _selection = null;
      _selectionOrigin = null;
    });
  }

  Widget _highlightToolbar() => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(24),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final item in const [
            (0xffffe082, 'Yellow'),
            (0xffa5d6a7, 'Green'),
            (0xfff48fb1, 'Pink')
          ])
            IconButton(
                key: ValueKey('epub-highlight-${item.$2}'),
                tooltip: 'Highlight ${item.$2.toLowerCase()}',
                icon: Icon(Icons.circle, color: Color(item.$1)),
                onPressed: () => _applyHighlight(item.$1)),
          if (_selection!.id.isNotEmpty)
            IconButton(
                key: const ValueKey('epub-highlight-remove'),
                tooltip: 'Remove highlight',
                icon: const Icon(Icons.format_color_reset),
                onPressed: () =>
                    _applyHighlight(_selection!.color, deleted: true)),
          IconButton(
              tooltip: 'Copy selected text',
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _selection!.text));
                setState(() => _selection = null);
              }),
          IconButton(
              tooltip: 'Close highlight toolbar',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selection = null)),
        ]),
      );

  String readingContext() {
    final buffer = StringBuffer();
    var character = 0;
    var located = false;
    for (final run in _runs) {
      if (!located &&
          (run.block > _anchor.block ||
              (run.block == _anchor.block && run.index >= _anchor.run))) {
        character = buffer.length +
            (run.block == _anchor.block && run.index == _anchor.run
                ? math.min(
                    _anchor.character, run.render.text.toPlainText().length)
                : 0);
        located = true;
      }
      // Use only actual text ranges; nested WidgetSpans have their own runs.
      final text = run.render.text.toPlainText();
      buffer.writeln(text.replaceAll('\uFFFC', ' '));
    }
    if (!located) character = buffer.length;
    return epubReadingWindow(buffer.toString(), character);
  }

  final _contentKey = GlobalKey();
  final _blockKeys = <int, GlobalKey>{};
  List<Widget>? _blocks;
  List<int> _starts = [];
  List<double> _breaks = [];
  List<_Run> _runs = [];
  Map<int, Rect> _rects = {};
  late EpubLocation _anchor;
  int _chapter = 0;
  int _page = 0;
  bool _lastPageRequested = false;
  bool _scheduled = false;
  Object? _signature;
  String? _error;
  Size viewport = Size.zero;
  double _dragDistance = 0;
  final _chapterCounts = <int, int>{};
  Object? _bookSignature;
  final _images = <ImageProvider, (ImageStream, ImageStreamListener)>{};
  final _pendingImages = <ImageProvider>{};

  /// Pagination must wait for decoded image dimensions, not a timed guess.
  void trackImage(ImageProvider provider) {
    if (_images.containsKey(provider)) return;
    _pendingImages.add(provider);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((image, _) {
      image.dispose();
      _pendingImages.remove(provider);
      if (mounted) _scheduleMeasure();
    }, onError: (Object error, StackTrace? stack) {
      _pendingImages.remove(provider);
      if (mounted) _scheduleMeasure();
    });
    _images[provider] = (stream, listener);
    stream.addListener(listener);
  }

  void _releaseTrackedImages() {
    for (final entry in _images.entries) {
      entry.value.$1.removeListener(entry.value.$2);
      // Measurements must not accumulate decoded images across the book.
      if (widget.measureOnly) entry.key.evict();
    }
    _images.clear();
    _pendingImages.clear();
  }

  @override
  void dispose() {
    _releaseTrackedImages();
    super.dispose();
  }

  void _recordCount(int chapter, int count, Object? signature) {
    if (!mounted || signature != _bookSignature) return;
    if (_chapterCounts[chapter] != count) {
      setState(() => _chapterCounts[chapter] = count);
    }
    _publishBook();
  }

  void _publishBook() {
    if (widget.onBookPage == null) return;
    if (_chapterCounts.length != _starts.length - 1 || _breaks.isEmpty) {
      widget.onBookPage!(null);
      return;
    }
    var preceding = 0;
    var total = 0;
    for (var i = 0; i < _starts.length - 1; i++) {
      final count = _chapterCounts[i]!;
      total += count;
      if (i < _chapter) preceding += count;
    }
    widget.onBookPage!(EpubPageInfo(
        preceding + _page + 1,
        total,
        _chapter == 0 && _page == 0,
        _chapter == _starts.length - 2 && _page == _breaks.length - 2));
  }

  @override
  void initState() {
    super.initState();
    _starts = {
      0,
      ...widget.chapterStarts.where((i) => i >= 0 && i < widget.blockCount),
      widget.blockCount
    }.toList()
      ..sort();
    if (_starts.length == 1) _starts.add(widget.blockCount);
    final location = widget.initialLocation;
    _anchor = location != null && location.block < widget.blockCount
        ? location
        : EpubLocation(widget.initialBlock);
    _chapter = _chapterFor(_anchor.block);
  }

  int _chapterFor(int block) {
    for (var i = 0; i < _starts.length - 1; i++) {
      if (block < _starts[i + 1]) return i;
    }
    return math.max(0, _starts.length - 2);
  }

  void jumpTo(int block) => jumpToLocation(EpubLocation(block));

  void jumpToLocation(EpubLocation location) {
    if (!mounted) return;
    _releaseTrackedImages();
    final index =
        location.block.clamp(0, math.max(0, widget.blockCount - 1)).toInt();
    if (_chapterFor(index) != _chapter) widget.onChapterChanged?.call();
    setState(() {
      _selection = null;
      _anchor = EpubLocation(index, location.run, location.character);
      _chapter = _chapterFor(index);
      _breaks = [];
      _runs = [];
      _blockKeys.clear();
      _blocks = null;
      _signature = null;
      _error = null;
    });
  }

  void next() {
    if (_breaks.isEmpty) return;
    if (_page < _breaks.length - 2) {
      _showPage(_page + 1);
    } else if (_chapter < _starts.length - 2) {
      jumpTo(_starts[_chapter + 1]);
    }
  }

  void previous() {
    if (_breaks.isEmpty) return;
    if (_page > 0) {
      _showPage(_page - 1);
    } else if (_chapter > 0) {
      final previousStart = _starts[_chapter - 1];
      jumpTo(previousStart);
      _lastPageRequested = true;
    }
  }

  void _showPage(int page) {
    setState(() {
      _selection = null;
      _page = page;
      _anchor = _anchorAt(_breaks[page]);
    });
    _publish();
  }

  EpubLocation _anchorAt(double y) {
    final block = _rects.entries
        .where((entry) => entry.value.bottom > y + 0.1)
        .firstOrNull
        ?.key;
    for (final run in _runs) {
      if (block != null && run.block != block) continue;
      if (run.offset.dy + run.render.size.height > y + 0.1) {
        final position = run.render.getPositionForOffset(
            Offset(0, math.max(0, y - run.offset.dy) + 0.1));
        return EpubLocation(run.block, run.index, position.offset);
      }
    }
    return EpubLocation(block ?? _starts[_chapter]);
  }

  void _publish() {
    if (!mounted || _breaks.isEmpty) return;
    widget.onPosition(_anchor.block);
    widget.onLocation?.call(_anchor);
    widget.onPage(EpubPageInfo(_page + 1, _breaks.length - 1, _page == 0,
        _page == _breaks.length - 2));
    _publishBook();
  }

  void _scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final root = _contentKey.currentContext?.findRenderObject();
    if (root is! RenderBox || !root.hasSize || viewport.height < 80) return;
    final spans = <PageSpan>[];
    final runs = <_Run>[];
    final blockRects = <int, Rect>{};
    for (final entry in _blockKeys.entries) {
      final block = entry.value.currentContext?.findRenderObject();
      if (block is! RenderBox || !block.hasSize) continue;
      blockRects[entry.key] = MatrixUtils.transformRect(
          block.getTransformTo(root), Offset.zero & block.size);
      var runIndex = 0;
      void visit(RenderObject child) {
        if (child is RenderParagraph && child.hasSize) {
          final offset = MatrixUtils.transformPoint(
              child.getTransformTo(root), Offset.zero);
          final selections = _textSelections(child.text);
          if (selections.isNotEmpty) {
            runs.add(_Run(entry.key, runIndex++, child, offset));
          }
          for (final selection in selections) {
            for (final box in child.getBoxesForSelection(selection,
                boxHeightStyle: ui.BoxHeightStyle.max)) {
              spans.add(PageSpan(offset.dy + box.top, offset.dy + box.bottom));
            }
          }
        } else if (child is RenderImage && child.hasSize) {
          final rect = MatrixUtils.transformRect(
              child.getTransformTo(root), Offset.zero & child.size);
          spans.add(PageSpan(rect.top, rect.bottom));
        }
        child.visitChildren(visit);
      }

      visit(block);
    }
    // Keep a heading with the first rendered line following it when it fits.
    for (final heading in widget.headingBlocks) {
      final rect = blockRects[heading];
      if (rect == null) continue;
      final following = spans
          .where((span) => span.top >= rect.bottom - 0.01)
          .toList()
        ..sort((a, b) => a.top.compareTo(b.top));
      if (following.isNotEmpty &&
          following.first.bottom - rect.top <= viewport.height) {
        spans.add(PageSpan(rect.top, following.first.bottom));
      }
    }
    try {
      final breaks = pageBreaks(root.size.height, viewport.height, spans);
      var y = blockRects[_anchor.block]?.top ?? 0.0;
      for (final run in runs) {
        if (run.block == _anchor.block && run.index == _anchor.run) {
          final length = run.render.text.toPlainText().length;
          final offset =
              _anchor.character.clamp(0, math.max(0, length - 1)).toInt();
          final boxes = run.render.getBoxesForSelection(TextSelection(
              baseOffset: offset, extentOffset: math.min(length, offset + 1)));
          if (boxes.isNotEmpty) y = run.offset.dy + boxes.first.top;
          break;
        }
      }
      var page = 0;
      while (page < breaks.length - 2 && breaks[page + 1] <= y + 0.01) {
        page++;
      }
      if (_lastPageRequested) page = breaks.length - 2;
      setState(() {
        _breaks = breaks;
        _runs = runs;
        _rects = blockRects;
        _page = page;
        _error = null;
        if (_lastPageRequested) _anchor = _anchorAt(breaks[page]);
        _lastPageRequested = false;
      });
      _publish();
      if (_pendingImages.isEmpty) {
        widget.onMeasured?.call(breaks.length - 1);
        if (widget.onBookPage != null) {
          _recordCount(_chapter, breaks.length - 1, _bookSignature);
        }
      }
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        viewport = constraints.biggest;
        final bookSignature =
            (viewport, widget.revision, MediaQuery.textScalerOf(context));
        if (_bookSignature != bookSignature) {
          _bookSignature = bookSignature;
          _chapterCounts.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _bookSignature == bookSignature) _publishBook();
          });
        }
        final probeChapter = widget.onBookPage == null || _breaks.isEmpty
            ? null
            : Iterable<int>.generate(_starts.length - 1)
                .where((i) => i != _chapter && !_chapterCounts.containsKey(i))
                .firstOrNull;
        final signature = (
          viewport,
          widget.revision,
          MediaQuery.textScalerOf(context),
          _chapter
        );
        if (_signature != signature) {
          _signature = signature;
          _blocks = null;
          _scheduleMeasure();
        }
        if (viewport.width < 100 || viewport.height < 80) {
          return const Center(child: Text('Make the window larger to read.'));
        }
        final start = _breaks.isEmpty ? 0.0 : _breaks[_page];
        final length = _breaks.isEmpty
            ? viewport.height
            : (_breaks[_page + 1] - start).clamp(0.0, viewport.height);
        return Focus(
          autofocus: !widget.measureOnly,
          canRequestFocus: !widget.measureOnly,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if ([
              LogicalKeyboardKey.arrowRight,
              LogicalKeyboardKey.pageDown,
              LogicalKeyboardKey.space
            ].contains(event.logicalKey)) {
              next();
              return KeyEventResult.handled;
            }
            if ([LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.pageUp]
                .contains(event.logicalKey)) {
              previous();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            key: _viewportKey,
            behavior: HitTestBehavior.opaque,
            onLongPressStart: widget.onHighlightChanged == null
                ? null
                : (details) => _startSelection(details.globalPosition),
            onLongPressMoveUpdate: widget.onHighlightChanged == null
                ? null
                : (details) => _extendSelection(details.globalPosition),
            onTapUp: widget.onHighlightChanged == null
                ? null
                : (details) => _tapHighlight(details.localPosition),
            onHorizontalDragStart: (_) => _dragDistance = 0,
            onHorizontalDragUpdate: (details) =>
                _dragDistance += details.primaryDelta ?? 0,
            onHorizontalDragEnd: (details) {
              if (_dragDistance.abs() > 40 ||
                  (details.primaryVelocity ?? 0).abs() > 100) {
                final direction = _dragDistance.abs() > 40
                    ? _dragDistance
                    : details.primaryVelocity!;
                direction < 0 ? next() : previous();
              }
            },
            child: Stack(children: [
              if (probeChapter != null)
                Positioned.fill(
                  child: ExcludeFocus(
                    child: ExcludeSemantics(
                      child: Offstage(
                        child: SizedBox(
                          width: viewport.width,
                          height: viewport.height,
                          child: PagedEpubContent(
                            key: ValueKey((bookSignature, probeChapter)),
                            measureOnly: true,
                            blockCount: widget.blockCount,
                            chapterStarts: widget.chapterStarts,
                            initialBlock: _starts[probeChapter],
                            blockBuilder: widget.blockBuilder,
                            revision: widget.revision,
                            headingBlocks: widget.headingBlocks,
                            onPosition: (_) {},
                            onPage: (_) {},
                            onMeasured: (count) => _recordCount(
                                probeChapter, count, bookSignature),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: viewport.width,
                    height: length,
                    child: ClipRect(
                        child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: Transform.translate(
                        offset: Offset(0, -start),
                        child:
                            NotificationListener<SizeChangedLayoutNotification>(
                          onNotification: (_) {
                            _scheduleMeasure();
                            return true;
                          },
                          child: SizeChangedLayoutNotifier(
                              child: SizedBox(
                            key: _contentKey,
                            width: viewport.width,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _blocks ??= [
                                for (var i = _starts[_chapter];
                                    i < _starts[_chapter + 1];
                                    i++)
                                  KeyedSubtree(
                                      key: _blockKeys.putIfAbsent(
                                          i, () => GlobalKey()),
                                      child: Builder(
                                          builder: (context) =>
                                              widget.blockBuilder(context, i)))
                              ],
                            ),
                          )),
                        ),
                      ),
                    )),
                  )),
              Positioned.fill(
                  child: IgnorePointer(
                      child: ClipRect(
                          child: Stack(children: [
                for (final highlight in [
                  ...widget.highlights,
                  if (_selection != null) _selection!
                ])
                  for (final rect in _highlightRects(highlight))
                    Positioned.fromRect(
                        rect: rect,
                        child: ColoredBox(color: highlight.paintColor)),
              ])))),
              if (_selection != null)
                Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(child: _highlightToolbar())),
              if (_error != null)
                Positioned.fill(
                    child: ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(_error!))))),
            ]),
          ),
        );
      });
}
