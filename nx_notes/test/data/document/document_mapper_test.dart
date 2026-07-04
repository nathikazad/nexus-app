import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/document/document_attr_keys.dart';
import 'package:nx_notes/data/document/document_mapper.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_publish.dart';

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

  test(
    'document update writes publish json and marks published edits dirty',
    () {
      final request = setModelRequestForUpdateDocument(
        _document(
          modelTypeName: 'Document',
          publish: const DocumentPublishState(
            enabled: true,
            dirty: false,
            lastPublishedHash: 'sha256:old',
            status: 'published',
          ),
        ),
      );

      final attributes = request.toJson()['attributes'] as List<dynamic>;
      final publish =
          attributes.cast<Map<String, dynamic>>().firstWhere(
                (attr) => attr['key'] == kDocumentAttrPublish,
              )['value']
              as Map<String, dynamic>;

      expect(publish['enabled'], true);
      expect(publish['dirty'], true);
      expect(publish['content_hash'], startsWith('sha256:'));
      expect(publish['last_published_hash'], 'sha256:old');
    },
  );

  test('document update does not mark unpublished edits dirty', () {
    final request = setModelRequestForUpdateDocument(
      _document(modelTypeName: 'Document'),
    );

    final attributes = request.toJson()['attributes'] as List<dynamic>;
    final publish =
        attributes.cast<Map<String, dynamic>>().firstWhere(
              (attr) => attr['key'] == kDocumentAttrPublish,
            )['value']
            as Map<String, dynamic>;

    expect(publish['enabled'], false);
    expect(publish['dirty'], false);
  });
}

NxDocument _document({
  required String modelTypeName,
  DocumentPublishState publish = const DocumentPublishState(
    enabled: false,
    dirty: false,
  ),
}) {
  return NxDocument(
    id: 42,
    title: 'Document',
    modelTypeName: modelTypeName,
    document: 'Body',
    jsonDocument: const <String, dynamic>{
      'format': 'appflowy_document',
      'document': <String, dynamic>{'type': 'page', 'children': []},
    },
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
    publish: publish,
  );
}
