import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'epub_reader_test.dart' show sampleEpub;

Uint8List rewritten(Map<String, String Function(String)> edits) {
  final source = ZipDecoder().decodeBytes(sampleEpub());
  final target = Archive();
  for (final file in source.files) {
    final edit = edits[file.name];
    final bytes = edit == null ? file.content : utf8.encode(edit(utf8.decode(file.content)));
    target.addFile(ArchiveFile(file.name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(target));
}

void main() {
  test('EPUB 3 with declared NCX retains both chapters and text', () async {
    final book = await EpubReader.readBook(rewritten({
      'content.opf': (s) => s.replaceFirst('version="2.0"', 'version="3.0"'),
    }), decodeCover: false);
    expect(book.Chapters!.map((c) => c.Title), ['First chapter', 'Second chapter']);
    expect(book.Chapters!.last.HtmlContent, contains('Target paragraph.'));
  });

  test('missing TOC parent preserves its valid child and other chapters', () async {
    final book = await EpubReader.readBook(rewritten({
      'toc.ncx': (s) => s.replaceFirst('<navMap>',
          '<navMap><navPoint id="cover"><navLabel><text>Old cover</text></navLabel><content src="missing.xhtml"/>')
          .replaceFirst('<navPoint id="two"', '</navPoint><navPoint id="two"'),
    }), decodeCover: false);
    expect(book.Chapters!.map((c) => c.Title), ['First chapter', 'Second chapter']);
  });
}
