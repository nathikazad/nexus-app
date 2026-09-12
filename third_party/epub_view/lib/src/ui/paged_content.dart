import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'page_breaks.dart';

class EpubPageInfo {
  const EpubPageInfo(this.page, this.pages, this.atStart, this.atEnd);
  final int page;
  final int pages;
  final bool atStart;
  final bool atEnd;
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

  @override
  State<PagedEpubContent> createState() => PagedEpubContentState();
}

class PagedEpubContentState extends State<PagedEpubContent> {
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

  void jumpTo(int block) {
    if (!mounted) return;
    final index = block.clamp(0, math.max(0, widget.blockCount - 1)).toInt();
    if (_chapterFor(index) != _chapter) widget.onChapterChanged?.call();
    setState(() {
      _anchor = EpubLocation(index);
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
    widget.onPage(EpubPageInfo(
        _page + 1,
        _breaks.length - 1,
        _chapter == 0 && _page == 0,
        _chapter == _starts.length - 2 && _page == _breaks.length - 2));
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
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        viewport = constraints.biggest;
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
          autofocus: true,
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
            behavior: HitTestBehavior.opaque,
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
