import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_docs/domain/document/document_publish.dart';
import 'package:nx_docs/domain/links/linked_model.dart';

final class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.title,
    required this.modelTypeName,
    required this.wordCount,
    required this.status,
    required this.topics,
    required this.areaTags,
    required this.tagsBySystem,
    required this.pinned,
    required this.updatedAt,
    required this.updatedLabel,
    required this.excerpt,
    required this.publish,
    required this.readingState,
    this.bookRank,
  });

  factory DocumentSummary.fromDocument(NxDocument document) {
    return DocumentSummary(
      id: document.id,
      title: document.title,
      modelTypeName: document.modelTypeName,
      wordCount: document.wordCount,
      status: document.status,
      topics: document.topics,
      areaTags: document.areaTags,
      tagsBySystem: document.tagsBySystem,
      pinned: document.pinned,
      updatedAt: document.updatedAt,
      updatedLabel: document.updatedLabel,
      excerpt: document.excerpt,
      publish: document.publish,
      readingState: document.readingState,
      bookRank: document.bookRank,
    );
  }

  final int id;
  final String title;
  final String modelTypeName;
  final int wordCount;
  final String status;
  final List<String> topics;
  final List<String> areaTags;
  final Map<String, List<String>> tagsBySystem;
  final bool pinned;
  final DateTime updatedAt;
  final String updatedLabel;
  final String excerpt;
  final DocumentPublishState publish;
  final String readingState;
  final int? bookRank;

  bool get isBook => modelTypeName == 'Book';

  /// Converts a catalog row into the existing presentation model without
  /// inventing a document body. Opening the row must still go through a
  /// [DocumentSession] to load complete content.
  NxDocument toDocument() {
    return NxDocument(
      id: id,
      title: title,
      modelTypeName: modelTypeName,
      document: '',
      jsonDocument: const <String, dynamic>{},
      wordCount: wordCount,
      status: status,
      topics: topics,
      areaTags: areaTags,
      tagsBySystem: tagsBySystem,
      pinned: pinned,
      updatedAt: updatedAt,
      updatedLabel: updatedLabel,
      versionNumber: 0,
      excerpt: excerpt,
      links: const <LinkedModel>[],
      publish: publish,
      readingState: readingState,
      bookRank: bookRank,
    );
  }
}
