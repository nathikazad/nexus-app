import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/document/document_publish.dart';

class NxDocument {
  const NxDocument({
    required this.id,
    required this.title,
    required this.modelTypeName,
    required this.document,
    required this.jsonDocument,
    required this.wordCount,
    required this.status,
    required this.topics,
    required this.areaTags,
    required this.tagsBySystem,
    required this.pinned,
    required this.updatedAt,
    required this.updatedLabel,
    required this.versionNumber,
    required this.excerpt,
    required this.links,
    this.publish = const DocumentPublishState(enabled: false, dirty: false),
    this.readingState = '',
    this.bookRank,
  });

  final int id;
  final String title;
  final String modelTypeName;
  final String document;
  final Map<String, dynamic> jsonDocument;
  final int wordCount;
  final String status;
  final List<String> topics;
  final List<String> areaTags;
  final Map<String, List<String>> tagsBySystem;
  final bool pinned;
  final DateTime updatedAt;
  final String updatedLabel;
  final int versionNumber;
  final String excerpt;
  final List<LinkedModel> links;
  final DocumentPublishState publish;
  final String readingState;
  final int? bookRank;

  bool get hasFullDocument =>
      document.isNotEmpty ||
      jsonDocument.containsKey('format') ||
      jsonDocument.containsKey('document');

  bool get isBook => modelTypeName == 'Book';

  NxDocument copyWith({
    String? title,
    String? modelTypeName,
    String? document,
    Map<String, dynamic>? jsonDocument,
    int? wordCount,
    String? status,
    List<String>? topics,
    List<String>? areaTags,
    Map<String, List<String>>? tagsBySystem,
    bool? pinned,
    DateTime? updatedAt,
    String? updatedLabel,
    int? versionNumber,
    String? excerpt,
    List<LinkedModel>? links,
    DocumentPublishState? publish,
    String? readingState,
    int? bookRank,
    bool clearBookRank = false,
  }) {
    return NxDocument(
      id: id,
      title: title ?? this.title,
      modelTypeName: modelTypeName ?? this.modelTypeName,
      document: document ?? this.document,
      jsonDocument: jsonDocument ?? this.jsonDocument,
      wordCount: wordCount ?? this.wordCount,
      status: status ?? this.status,
      topics: topics ?? this.topics,
      areaTags: areaTags ?? this.areaTags,
      tagsBySystem: tagsBySystem ?? this.tagsBySystem,
      pinned: pinned ?? this.pinned,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedLabel: updatedLabel ?? this.updatedLabel,
      versionNumber: versionNumber ?? this.versionNumber,
      excerpt: excerpt ?? this.excerpt,
      links: links ?? this.links,
      publish: publish ?? this.publish,
      readingState: readingState ?? this.readingState,
      bookRank: clearBookRank ? null : bookRank ?? this.bookRank,
    );
  }
}
