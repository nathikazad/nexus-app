import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Parsing happens outside the UI isolate. No server or WebView is required.
Future<EpubBook> loadLocalEpub(String path) => compute(_readBook, path);

Future<EpubBook> _readBook(String path) async {
  final file = File(path);
  if (await file.length() > 64 * 1024 * 1024) {
    throw const FormatException('This reader supports EPUB files up to 64 MB.');
  }
  return EpubReader.readBook(await file.readAsBytes(), decodeCover: false);
}

/// KGQL stays outside the reader boundary: local file plus optional EPUB CFI.
class EpubReaderPage extends StatefulWidget {
  const EpubReaderPage({
    required this.path,
    required this.title,
    this.target,
    this.loadBook = loadLocalEpub,
    super.key,
  });
  final String path;
  final String title;
  final String? target;
  final Future<EpubBook> Function(String path) loadBook;

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  late final EpubController _controller;
  final _opened = Stopwatch()..start();
  bool _ready = false;
  double _font = 19;

  @override
  void initState() {
    super.initState();
    _controller = EpubController(
      document: widget.loadBook(widget.path),
      epubCfi: widget.target,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Smaller text',
          onPressed: _font > 13 ? () => setState(() => _font -= 2) : null,
          icon: const Icon(Icons.text_decrease),
        ),
        IconButton(
          tooltip: 'Larger text',
          onPressed: _font < 31 ? () => setState(() => _font += 2) : null,
          icon: const Icon(Icons.text_increase),
        ),
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Table of contents',
            onPressed: _ready
                ? () => Scaffold.of(context).openEndDrawer()
                : null,
            icon: const Icon(Icons.list),
          ),
        ),
      ],
    ),
    endDrawer: Drawer(
      child: SafeArea(
        child: EpubViewTableOfContents(
          controller: _controller,
          itemBuilder: (context, index, chapter, count) => ListTile(
            title: Text(chapter.title?.trim() ?? 'Section ${index + 1}'),
            onTap: () {
              Navigator.of(context).pop();
              _controller.jumpTo(index: chapter.startIndex);
            },
          ),
        ),
      ),
    ),
    body: EpubView(
      paginated: true,
      controller: _controller,
      onExternalLinkPressed: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'External links are not opened by the offline reader.',
            ),
          ),
        );
      },
      onDocumentLoaded: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _opened.stop();
            setState(() => _ready = true);
          }
        });
      },
      builders: EpubViewBuilders<DefaultBuilderOptions>(
        options: DefaultBuilderOptions(
          loaderSwitchDuration: Duration.zero,
          textStyle: TextStyle(fontSize: _font, height: 1.6),
        ),
        loaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not open this EPUB.\n$error'),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ValueListenableBuilder<EpubPageInfo?>(
          valueListenable: _controller.pageListenable,
          builder: (context, page, _) => Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: page != null && !page.atStart
                    ? _controller.previousPage
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: EpubViewActualChapter(
                  controller: _controller,
                  loader: const Text('Opening EPUB…'),
                  builder: (value) => Text(
                    value?.chapter?.Title ?? 'Opening EPUB…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (page != null)
                Text(
                  'Page ${page.page} of ${page.pages}',
                  key: const ValueKey('epub-page-count'),
                ),
              IconButton(
                tooltip: 'Next page',
                onPressed: page != null && !page.atEnd
                    ? _controller.nextPage
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
