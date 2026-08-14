class DocumentIdentity {
  const DocumentIdentity({required this.id, required this.modelType});

  final int id;
  final String modelType;

  @override
  bool operator ==(Object other) {
    return other is DocumentIdentity &&
        other.id == id &&
        other.modelType == modelType;
  }

  @override
  int get hashCode => Object.hash(id, modelType);
}

DocumentIdentity? documentIdentityFromKgqlHref(String? href) {
  if (href == null || href.trim().isEmpty) return null;
  final uri = Uri.tryParse(href.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'kgql' ||
      uri.host.trim().isEmpty ||
      uri.pathSegments.isEmpty) {
    return null;
  }
  final id = int.tryParse(uri.pathSegments.first);
  return id == null ? null : DocumentIdentity(id: id, modelType: uri.host);
}

class DocumentContent {
  const DocumentContent({
    required this.identity,
    required this.title,
    required this.plainText,
    required this.jsonDocument,
    required this.updatedAt,
  });

  final DocumentIdentity identity;
  final String title;
  final String plainText;
  final Map<String, dynamic> jsonDocument;
  final DateTime updatedAt;

  DocumentContent copyWith({
    String? title,
    String? plainText,
    Map<String, dynamic>? jsonDocument,
    DateTime? updatedAt,
  }) {
    return DocumentContent(
      identity: identity,
      title: title ?? this.title,
      plainText: plainText ?? this.plainText,
      jsonDocument: jsonDocument ?? this.jsonDocument,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract interface class DocumentContentRepository {
  Future<DocumentContent?> load(DocumentIdentity identity);

  Future<DocumentContent> save(DocumentContent content);
}
