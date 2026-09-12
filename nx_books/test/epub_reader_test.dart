import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:appflowy_editor/src/plugins/pdf/html_to_pdf_encoder.dart';
import 'package:archive/archive.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:nx_books/epub/epub_reader_page.dart';

Uint8List sampleEpub() {
  final archive = Archive();
  void add(String name, String text) {
    final bytes = utf8.encode(
      name == 'toc.ncx'
          ? text.replaceFirst(
              '<navMap>',
              '<head/><docTitle><text>Reader test</text></docTitle><navMap>',
            )
          : text,
    );
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf"/></rootfiles></container>',
  );
  add(
    'content.opf',
    '''<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Reader test</dc:title><dc:creator>Nexus</dc:creator><dc:identifier id="id">nexus-test</dc:identifier><meta name="cover" content="cover"/></metadata><manifest><item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="two.xhtml" media-type="application/xhtml+xml"/><item id="cover" href="cover.png" media-type="image/png"/></manifest><spine toc="toc"><itemref idref="one"/><itemref idref="two"/></spine></package>''',
  );
  add(
    'toc.ncx',
    '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><navMap><navPoint id="one" playOrder="1"><navLabel><text>First chapter</text></navLabel><content src="one.xhtml"/></navPoint><navPoint id="two" playOrder="2"><navLabel><text>Second chapter</text></navLabel><content src="two.xhtml"/></navPoint></navMap></ncx>',
  );
  add(
    'one.xhtml',
    '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>First heading</h1><img src="cover.png"/><p>First paragraph.</p></body></html>',
  );
  add(
    'two.xhtml',
    '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>Second heading</h1><p id="target">Target paragraph.</p></body></html>',
  );
  final png = image.encodePng(image.Image(width: 20, height: 20));
  archive.addFile(ArchiveFile('cover.png', png.length, png));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('parser migration preserves text, images and cover decoding', () async {
    final book = await EpubReader.readBook(sampleEpub());
    expect(book.Title, 'Reader test');
    expect(book.Chapters, hasLength(2));
    expect(book.CoverImage!.width, 20);
    expect(book.Content!.Images!['cover.png']!.Content, isA<Uint8List>());
    final lean = await EpubReader.readBook(sampleEpub(), decodeCover: false);
    expect(lean.CoverImage, isNull);
    expect(lean.Content!.Images, isNotEmpty);
  });

  test('AppFlowy PDF export still handles text and local images', () async {
    final dir = await Directory.systemTemp.createTemp('nx-pdf-compat-');
    addTearDown(() => dir.delete(recursive: true));
    final png = File('${dir.path}/image.png');
    await png.writeAsBytes(image.encodePng(image.Image(width: 20, height: 20)));
    final pdf = await PdfHTMLEncoder(fontFallback: []).convert(
      '# Test heading\n\nA **bold** paragraph.\n\n![test](${png.path})',
    );
    final bytes = await pdf.save();
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(latin1.decode(bytes), matches(RegExp(r'/Subtype\s*/Image')));
  });

  testWidgets('reader renders, changes chapter, and round-trips a CFI', (
    tester,
  ) async {
    final controller = EpubController(
      document: EpubReader.readBook(sampleEpub()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EpubView(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('First heading', findRichText: true),
      findsWidgets,
    );
    final chapters = controller.tableOfContents();
    expect(chapters, hasLength(2));
    controller.jumpTo(index: chapters.last.startIndex);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Second heading', findRichText: true),
      findsWidgets,
    );
    final cfi = controller.generateEpubCfi();
    expect(cfi, startsWith('epubcfi('));
    controller.gotoEpubCfi(cfi!);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing before parsing completes is safe', (tester) async {
    final pending = Completer<EpubBook>();
    final controller = EpubController(document: pending.future);
    await tester.pumpWidget(
      MaterialApp(home: EpubView(controller: controller)),
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    pending.complete(await EpubReader.readBook(sampleEpub()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('local loader rejects malformed files', () async {
    final dir = await Directory.systemTemp.createTemp('nx-epub-invalid-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File(
      '${dir.path}/invalid.epub',
    ).writeAsString('invalid');
    await expectLater(loadLocalEpub(file.path), throwsA(anything));
  });

  final realPath = Platform.environment['NX_EPUB_TEST_PATH'];
  testWidgets('full reader page reserves space while loading and goes back', (
    tester,
  ) async {
    final book = await EpubReader.readBook(sampleEpub());
    var passage = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EpubReaderPage(
                  path: 'test.epub',
                  title: 'Test book',
                  textScaleFactor: 1.3,
                  savedPosition: const {'font_size': 31},
                  onReadingContextChanged: (text) => passage = text,
                  loadBook: (_) => Future.value(book),
                ),
              ),
            ),
            child: const Text('Open test book'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open test book'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final view = tester.widget<EpubView>(find.byType(EpubView));
    expect(view.builders.options.textStyle.fontSize, closeTo(24.7, 0.001));
    expect(find.byTooltip('Smaller text'), findsNothing);
    expect(find.byTooltip('Larger text'), findsNothing);
    expect(tester.getSize(find.byType(EpubView)).height, greaterThan(300));
    await tester.runAsync(() => view.controller.document);
    await tester.pumpAndSettle();
    final pageCount = find.byKey(const ValueKey('epub-page-count'));
    expect(
      tester.getRect(find.byTooltip('Previous book page')).right,
      lessThanOrEqualTo(tester.getRect(pageCount).left),
    );
    expect(
      tester.getRect(find.byTooltip('Next book page')).left,
      greaterThanOrEqualTo(tester.getRect(pageCount).right),
    );
    expect(
      tester.getRect(pageCount).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(EpubView)).top),
    );
    expect(
      tester.getRect(find.byTooltip('Next book page')).right,
      lessThanOrEqualTo(
        tester.getRect(find.byTooltip('Table of contents')).left,
      ),
    );
    expect(tester.widget<Text>(pageCount).data, isNot(contains('Page')));
    final chapterPageCount = find.byKey(
      const ValueKey('epub-chapter-page-count'),
    );
    final chapterName = find.byKey(const ValueKey('epub-chapter-name'));
    expect(
      tester.getRect(find.byTooltip('Previous chapter page')).left,
      closeTo(tester.getRect(chapterName).right, 8),
    );
    expect(
      DefaultTextStyle.of(tester.element(chapterPageCount)).style,
      DefaultTextStyle.of(tester.element(chapterName)).style,
    );
    expect(
      tester.getCenter(chapterPageCount).dx,
      greaterThan(tester.getCenter(chapterName).dx),
    );
    expect(
      tester.getCenter(chapterPageCount).dy,
      closeTo(tester.getCenter(chapterName).dy, 1),
    );
    // Native image decoding completes outside the test's fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(view.controller.bookPageListenable.value?.pages, 2);
    expect(tester.widget<Text>(chapterPageCount).data, '1 of 1');
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Next chapter page',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Next book page',
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(passage, contains('First heading'));
    await tester.tap(find.byTooltip('Next book page'));
    await tester.pumpAndSettle();
    expect(view.controller.bookPageListenable.value!.page, 2);
    expect(passage, contains('Second heading'));
    expect(tester.widget<Text>(chapterPageCount).data, '1 of 1');
    await tester.tap(find.byTooltip('Previous book page'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(view.controller.bookPageListenable.value!.page, 1);
    expect(
      find.textContaining('First heading', findRichText: true),
      findsWidgets,
    );
    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second chapter').last);
    await tester.pumpAndSettle();
    expect(passage, contains('Second heading'));
    expect(passage, isNot(contains('First heading')));
    expect(
      find.textContaining('Second heading', findRichText: true),
      findsWidgets,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open test book'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real book computes a whole-book total without moving the reader',
    (tester) async {
      final book = await tester.runAsync(() => loadLocalEpub(realPath!));
      final controller = EpubController(document: Future.value(book));
      final elapsed = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpubView(controller: controller, paginated: true),
          ),
        ),
      );
      for (
        var i = 0;
        i < 300 && controller.bookPageListenable.value == null;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.bookPageListenable.value, isNotNull);
      expect(controller.bookPageListenable.value!.page, 1);
      expect(
        controller.bookPageListenable.value!.pages,
        greaterThan(controller.pageListenable.value!.pages),
      );
      debugPrint(
        'Whole book: ${controller.bookPageListenable.value!.pages} pages, ${elapsed.elapsedMilliseconds}ms test layout',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
    skip: realPath == null,
  );

  testWidgets('real book renders and visits every contents entry', (
    tester,
  ) async {
    final book = await tester.runAsync(() => loadLocalEpub(realPath!));
    final controller = EpubController(document: Future.value(book));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EpubView(controller: controller, paginated: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.isBookLoaded.value, isTrue);
    final toc = controller.tableOfContents();
    expect(toc, isNotEmpty);
    final contents = toc.firstWhere(
      (entry) => entry.title == 'Table of Contents',
    );
    controller.jumpTo(index: contents.startIndex);
    await tester.pumpAndSettle();
    final html = tester
        .widgetList<Html>(find.byType(Html))
        .firstWhere(
          (widget) => widget.data?.contains('Scale Economies') ?? false,
        );
    final link = html_parser
        .parse(html.data)
        .querySelectorAll('a')
        .firstWhere((element) => element.text.contains('Scale Economies'));
    html.onLinkTap!(link.attributes['href'], {}, link);
    await tester.pumpAndSettle();
    expect(
      controller.currentValueListenable.value?.chapter?.Title,
      'Chapter 1: Scale Economies',
    );
    for (final chapter in toc) {
      controller.jumpTo(index: chapter.startIndex);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: chapter.title);
      expect(controller.pageListenable.value, isNotNull, reason: chapter.title);
      expect(
        find.textContaining('An item is taller'),
        findsNothing,
        reason: chapter.title,
      );
      final count = controller.pageListenable.value!.pages;
      for (var page = 1; page < count; page++) {
        controller.nextPage();
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${chapter.title} page $page',
        );
        expect(controller.pageListenable.value!.page, page + 1);
      }
    }
    debugPrint('Visited ${toc.length} real-book contents entries');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }, skip: realPath == null);

  test('real book parsing measurement', () async {
    final sw = Stopwatch()..start();
    final book = await loadLocalEpub(realPath!);
    expect(book.Chapters, isNotEmpty);
    expect(book.Content!.Html, isNotEmpty);
    // Timing here includes isolate startup; release-app measurements are separate.
    debugPrint(
      'EPUB parsed in ${sw.elapsedMilliseconds}ms; ${book.Chapters!.length} top-level chapters; ${book.Content!.Images!.length} images',
    );
  }, skip: realPath == null);
}
