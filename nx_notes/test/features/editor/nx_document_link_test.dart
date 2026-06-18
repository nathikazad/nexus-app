import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/features/editor/nx_document_link.dart';

void main() {
  test('parses current and legacy document hrefs', () {
    expect(nxDocumentIdFromHref('kgql://Document/4209'), 4209);
    expect(nxDocumentIdFromHref('kgql://Essay/4209'), 4209);
  });

  test('ignores non-document hrefs', () {
    expect(nxDocumentIdFromHref('kgql://Project/14'), isNull);
    expect(nxDocumentIdFromHref('https://example.com'), isNull);
  });
}
