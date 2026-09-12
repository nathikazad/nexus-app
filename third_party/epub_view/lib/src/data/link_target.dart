import 'package:epubx/epubx.dart';

import 'models/paragraph.dart';

/// Resolve against the source document, not the whole book's first matching ID.
/// Navigation uses the renderer's paragraph index directly, without a lossy
/// paragraph -> generated CFI -> paragraph round trip.
int? resolveLinkTarget({
  required String href,
  required int sourceIndex,
  required List<EpubChapter> chapters,
  required List<Paragraph> paragraphs,
}) {
  final link = Uri.tryParse(href);
  if (link == null || link.hasScheme || link.hasAuthority) return null;
  Uri documentUri(String filename) => Uri(path: '/$filename').normalizePath();
  final source = chapters[paragraphs[sourceIndex].chapterIndex].ContentFileName;
  if (source == null) return null;
  final target = documentUri(source).resolveUri(link).normalizePath();
  for (var i = 0; i < paragraphs.length; i++) {
    final paragraph = paragraphs[i];
    final filename = chapters[paragraph.chapterIndex].ContentFileName;
    if (filename == null || documentUri(filename).path != target.path) continue;
    if (target.fragment.isEmpty) return i;
    final String id;
    try {
      id = Uri.decodeComponent(target.fragment);
    } on FormatException {
      return null;
    }
    final element = paragraph.element;
    if (element.id == id ||
        element.attributes['name'] == id ||
        element.querySelectorAll('[id], a[name]').any(
              (child) => child.id == id || child.attributes['name'] == id,
            )) {
      return i;
    }
    // Flattened divs remain DOM ancestors even though they are not blocks.
    for (var parent = element.parent; parent != null; parent = parent.parent) {
      if (parent.id == id) return i;
    }
  }
  return null;
}
