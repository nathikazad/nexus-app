import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/document/document_attr_keys.dart';
import 'package:nx_notes/data/document/document_mapper.dart';
import 'package:nx_notes/domain/document/document.dart';

void main() {
  test('book update writes the same tag payload as a document update', () {
    final request = setModelRequestForUpdateDocument(
      _document(modelTypeName: 'Book'),
    );

    final tags = request.toJson()['tags'] as List<dynamic>;

    expect(
      tags,
      containsAll(<Map<String, Object>>[
        <String, Object>{
          'system': kDocumentStatusTagSystem,
          'nodes': <String>['Draft'],
        },
        <String, Object>{
          'system': kDocumentTopicTagSystem,
          'nodes': <String>['Technical'],
          'clear': true,
        },
      ]),
    );
  });
}

NxDocument _document({required String modelTypeName}) {
  return NxDocument(
    id: 42,
    title: 'Document',
    modelTypeName: modelTypeName,
    document: 'Body',
    jsonDocument: const <String, dynamic>{},
    wordCount: 1,
    status: 'Draft',
    topics: const <String>['Technical'],
    areaTags: const <String>[],
    tagsBySystem: const <String, List<String>>{},
    pinned: false,
    updatedAt: DateTime(2026),
    updatedLabel: 'just now',
    versionNumber: 0,
    excerpt: 'Body',
    links: const [],
  );
}
