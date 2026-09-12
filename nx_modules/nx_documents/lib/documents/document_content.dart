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
    this.modelTypeName,
    this.modelRelations = const [],
  });

  final DocumentIdentity identity;
  final String title;
  final String plainText;
  final Map<String, dynamic> jsonDocument;
  final DateTime updatedAt;

  /// Actual subtype and links from KGQL, distinct from a broad lookup identity.
  final String? modelTypeName;
  final List<DocumentModelRelation> modelRelations;

  DocumentContent copyWith({
    String? title,
    String? plainText,
    Map<String, dynamic>? jsonDocument,
    DateTime? updatedAt,
  }) {
    return DocumentContent(
      identity: identity,
      modelTypeName: modelTypeName,
      modelRelations: modelRelations,
      title: title ?? this.title,
      plainText: plainText ?? this.plainText,
      jsonDocument: jsonDocument ?? this.jsonDocument,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DocumentModelRelation {
  const DocumentModelRelation(this.id, this.modelType, this.relationName);
  final int id;
  final String modelType;
  final String? relationName;
  Map<String, dynamic> toJson() => {
    'id': id,
    'model_type': modelType,
    'relation_name': relationName,
  };
  factory DocumentModelRelation.fromJson(Map json) => DocumentModelRelation(
    json['id'] as int,
    json['model_type'] as String,
    json['relation_name'] as String?,
  );
}

abstract interface class DocumentContentRepository {
  Future<DocumentContent?> load(DocumentIdentity identity);

  Future<DocumentContent> save(DocumentContent content);
}
