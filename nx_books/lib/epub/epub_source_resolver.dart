import 'package:epub_view/epub_view.dart';
// This adapter deliberately tracks the current renderer's parser contract.
// ignore: implementation_imports
import 'package:epub_view/src/data/epub_parser.dart' as parser;
import 'package:path/path.dart' as path;
import 'book_source.dart';

String _normalized(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Adapter for the current native renderer. Stored references never contain
/// its block indexes. Returns the start of the uniquely identified paragraph.
EpubLocation resolveEpubSource(EpubBook book, BookSource source) {
  final chapters = parser.parseChapters(book);
  final paragraphs = parser
      .parseParagraphs(chapters, book.Content)
      .flatParagraphs;
  final candidates = <int>[];
  final anchors = <int>[];
  final quote = source.exact == null ? null : _normalized(source.exact!);
  for (var i = 0; i < paragraphs.length; i++) {
    final paragraph = paragraphs[i];
    final resource = path.posix.normalize(
      path.posix.join(
        book.Schema?.ContentDirectoryPath ?? '',
        chapters[paragraph.chapterIndex].ContentFileName ?? '',
      ),
    );
    if (resource != source.resource) continue;
    final element = paragraph.element;
    if (source.fragment != null &&
        (element.id == source.fragment ||
            element
                .querySelectorAll('[id]')
                .any((e) => e.id == source.fragment))) {
      anchors.add(i);
    }
    if (quote == null) continue;
    final text = _normalized(element.text);
    var start = 0;
    while (start <= text.length) {
      final match = text.indexOf(quote, start);
      if (match < 0) break;
      if ((source.prefix == null ||
              text
                  .substring(0, match)
                  .trimRight()
                  .endsWith(_normalized(source.prefix!))) &&
          (source.suffix == null ||
              text
                  .substring(match + quote.length)
                  .trimLeft()
                  .startsWith(_normalized(source.suffix!)))) {
        candidates.add(i);
      }
      start = match + quote.length;
    }
  }
  // A supplied quote validates the anchor; otherwise an exact, unique quote
  // is the fallback. Never silently choose the first ambiguous occurrence.
  if (anchors.length == 1 &&
      (quote == null ||
          candidates.where((i) => i == anchors.single).length == 1)) {
    return EpubLocation(anchors.single);
  }
  if (candidates.length == 1) return EpubLocation(candidates.single);
  throw StateError(
    candidates.isEmpty
        ? 'The source passage could not be found in this EPUB.'
        : 'This source passage occurs more than once; its reference needs more context.',
  );
}
