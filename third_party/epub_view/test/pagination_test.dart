import 'package:epub_view/src/ui/page_breaks.dart';
import 'package:epub_view/src/ui/paged_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('whole-book pagination counts sequentially and reflows',
      (tester) async {
    final key = GlobalKey<PagedEpubContentState>();
    EpubPageInfo? chapter;
    EpubPageInfo? book;
    var maxMounted = 0;
    Future<void> show(double font) async {
      await tester.pumpWidget(MaterialApp(
          home: Center(
              child: SizedBox(
        width: 400,
        height: 300,
        child: PagedEpubContent(
          key: key,
          blockCount: 3,
          chapterStarts: const [0, 1, 2],
          revision: font,
          onPosition: (_) {},
          onPage: (p) => chapter = p,
          onBookPage: (p) => book = p,
          blockBuilder: (_, i) => Text(List.filled(130, 'chapter$i').join(' '),
              style: TextStyle(fontSize: font)),
        ),
      ))));
      for (var i = 0; i < 20; i++) {
        await tester.pump();
        final mounted = find
            .byType(PagedEpubContent, skipOffstage: false)
            .evaluate()
            .length;
        if (mounted > maxMounted) maxMounted = mounted;
      }
      await tester.pumpAndSettle();
    }

    await show(18);
    final pages = chapter!.pages;
    expect(book!.pages, pages * 3);
    expect(book!.page, 1);
    expect(maxMounted, lessThanOrEqualTo(2));
    expect(find.byType(PagedEpubContent, skipOffstage: false), findsOneWidget);
    key.currentState!.jumpTo(1);
    await tester.pumpAndSettle();
    expect(chapter!.page, 1);
    expect(book!.page, pages + 1);
    key.currentState!.previous();
    await tester.pumpAndSettle();
    expect(chapter!.page, pages);
    expect(book!.page, pages);
    final total = book!.pages;
    await show(26);
    expect(book!.pages, greaterThan(total));
    expect(maxMounted, lessThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('saved location restores within a long paragraph after remount',
      (tester) async {
    EpubLocation? location;
    EpubPageInfo? page;
    var key = GlobalKey<PagedEpubContentState>();
    final text = List.generate(1000, (i) => 'word$i').join(' ');
    Future<void> mount(EpubLocation? initial) async {
      await tester.pumpWidget(MaterialApp(
          home: SizedBox(
        width: 400,
        height: 400,
        child: PagedEpubContent(
          key: key,
          blockCount: 1,
          chapterStarts: const [0],
          revision: 1,
          initialLocation: initial,
          onPosition: (_) {},
          onLocation: (value) => location = value,
          onPage: (value) => page = value,
          blockBuilder: (_, __) =>
              Text(text, style: const TextStyle(fontSize: 20)),
        ),
      )));
      await tester.pumpAndSettle();
    }

    await mount(null);
    key.currentState!.next();
    key.currentState!.next();
    await tester.pumpAndSettle();
    expect(page!.page, 3);
    final saved = EpubLocation.fromJson(location!.toJson());
    expect(saved!.character, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    key = GlobalKey<PagedEpubContentState>();
    await mount(saved);
    expect(page!.page, 3);
    expect(location!.character, saved.character);
    expect(EpubLocation.fromJson({'version': 2}), isNull);
    expect(
        EpubLocation.fromJson(
            {'version': 1, 'block': -1, 'run': 0, 'character': 0}),
        isNull);
  });
  test('page ranges cover content without splitting a line or image', () {
    final spans = [
      for (var i = 0; i < 30; i++) PageSpan(i * 21.0, (i + 1) * 21.0)
    ];
    final breaks = pageBreaks(630, 100, spans);
    expect(breaks.first, 0);
    expect(breaks.last, 630);
    for (var i = 1; i < breaks.length; i++) {
      expect(breaks[i] - breaks[i - 1], inInclusiveRange(1, 100));
      for (final span in spans) {
        expect(breaks[i] > span.top && breaks[i] < span.bottom, isFalse);
      }
    }
    expect(pageBreaks(250, 100, [const PageSpan(80, 170)]), [0, 80, 180, 250]);
  });

  test(
      'oversize atomic content fails explicitly instead of clipping or looping',
      () {
    expect(
        () => pageBreaks(300, 100, [const PageSpan(0, 200)]), throwsStateError);
  });

  testWidgets('font and dimension changes reflow around the current text',
      (tester) async {
    final key = GlobalKey<PagedEpubContentState>();
    EpubPageInfo? info;
    final text = List.generate(600, (i) => 'word$i').join(' ');
    Future<void> show(double width, double height, double font) async {
      await tester.pumpWidget(MaterialApp(
          home: Center(
              child: SizedBox(
        width: width,
        height: height,
        child: PagedEpubContent(
          key: key,
          blockCount: 1,
          chapterStarts: const [0],
          revision: font,
          onPosition: (_) {},
          onPage: (page) => info = page,
          // HTML uses nested WidgetSpans; the outer placeholder must not be
          // treated as a single unbreakable line spanning the entire chapter.
          blockBuilder: (_, index) => RichText(
              text: TextSpan(children: [
            WidgetSpan(
                child: SizedBox(
                    width: width,
                    child: Text(text,
                        style: TextStyle(fontSize: font, height: 1.5)))),
          ])),
        ),
      ))));
      await tester.pumpAndSettle();
    }

    await show(500, 400, 18);
    final originalPages = info!.pages;
    expect(originalPages, greaterThan(3));
    key.currentState!.next();
    key.currentState!.next();
    await tester.pumpAndSettle();
    expect(info!.page, 3);
    RenderParagraph paragraph() =>
        tester.renderObject<RenderParagraph>(find.text(text));
    int topCharacter() => paragraph()
        .getPositionForOffset(paragraph().globalToLocal(
            tester.getTopLeft(find.byKey(key)) + const Offset(1, 1)))
        .offset;
    int bottomCharacter() => paragraph()
        .getPositionForOffset(paragraph().globalToLocal(
            tester.getBottomRight(find.byKey(key)) - const Offset(1, 1)))
        .offset;
    final anchor = topCharacter();
    await show(320, 300, 24);
    expect(info!.pages, greaterThan(originalPages));
    expect(topCharacter(), lessThanOrEqualTo(anchor));
    expect(bottomCharacter(), greaterThan(anchor));
    expect(tester.takeException(), isNull);
    final currentPage = info!.page;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(info!.page, currentPage + 1);
    await tester.drag(find.byKey(key), const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(info!.page, currentPage);
  });

  testWidgets('next and previous cross chapter boundaries', (tester) async {
    final key = GlobalKey<PagedEpubContentState>();
    EpubPageInfo? info;
    int? position;
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
      width: 400,
      height: 400,
      child: PagedEpubContent(
        key: key,
        blockCount: 2,
        chapterStarts: const [0, 1],
        revision: 1,
        onPosition: (i) => position = i,
        onPage: (p) => info = p,
        blockBuilder: (_, i) => Text('Chapter $i'),
      ),
    )));
    await tester.pumpAndSettle();
    expect(info!.atStart, isTrue);
    key.currentState!.next();
    await tester.pumpAndSettle();
    expect(position, 1);
    expect(info!.atEnd, isTrue);
    key.currentState!.previous();
    await tester.pumpAndSettle();
    expect(position, 0);
    expect(info!.atStart, isTrue);
  });
}
