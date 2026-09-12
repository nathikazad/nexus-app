import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:epub_view/epub_view.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/epub/epub_reader_page.dart';
import 'epub_reader_test.dart' show sampleEpub;

void main() {
  testWidgets('nested EPUB images render and missing images have a placeholder', (
    tester,
  ) async {
    final input = ZipDecoder().decodeBytes(sampleEpub());
    final output = Archive();
    for (final file in input.files) {
      var name = file.name;
      var bytes = file.content as List<int>;
      if (name == 'cover.png') {
        name = 'OEBPS/image/cover.png';
      } else if (name.endsWith('.xhtml')) {
        name = 'OEBPS/xhtml/$name';
        final html = utf8
            .decode(bytes)
            .replaceAll('src="cover.png"', 'src="../image/cover.png"')
            .replaceFirst(
              '</body>',
              '<p><img src="../image/missing.png" alt="Missing diagram"/></p></body>',
            );
        bytes = utf8.encode(html);
      } else if (name == 'content.opf' || name == 'toc.ncx') {
        bytes = utf8.encode(
          utf8
              .decode(bytes)
              .replaceAll('one.xhtml', 'OEBPS/xhtml/one.xhtml')
              .replaceAll('two.xhtml', 'OEBPS/xhtml/two.xhtml')
              .replaceAll('cover.png', 'OEBPS/image/cover.png'),
        );
      }
      output.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    final book = await EpubReader.readBook(ZipEncoder().encode(output));
    await tester.pumpWidget(
      MaterialApp(
        home: EpubReaderPage(
          path: 'fixture.epub',
          title: 'Nested images',
          loadBook: (_) async => book,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
    expect(find.text('Image unavailable: Missing diagram'), findsWidgets);
    expect(find.text('Image could not be displayed'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
