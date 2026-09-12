import 'package:epub_view/src/data/link_target.dart';
import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';

void main() {
  test('links resolve exact files and nested anchors relative to their source',
      () {
    final chapters = [
      EpubChapter()..ContentFileName = 'Text/toc.xhtml',
      EpubChapter()..ContentFileName = 'Chapters/one.xhtml',
    ];
    final paragraphs = [
      Paragraph(parse('<p id="same">TOC</p>').body!.children.single, 0),
      Paragraph(parse('<h1>Chapter</h1>').body!.children.single, 1),
      Paragraph(
          parse('<div><p><span id="same">Target</span></p></div>')
              .body!
              .children
              .single,
          1),
      Paragraph(
          parse('<p id="with space">Encoded</p>').body!.children.single, 1),
    ];
    int? resolve(String href, {int source = 0}) => resolveLinkTarget(
          href: href,
          sourceIndex: source,
          chapters: chapters,
          paragraphs: paragraphs,
        );
    expect(resolve('../Chapters/one.xhtml'), 1);
    expect(resolve('../Chapters/one.xhtml#same'), 2);
    expect(resolve('#same', source: 1), 2);
    expect(resolve('#with%20space', source: 1), 3);
    expect(resolve('../Chapters/not-one.xhtml#same'), isNull);
    expect(resolve('#missing'), isNull);
    expect(resolve('https://example.com/one.xhtml'), isNull);
  });
}
