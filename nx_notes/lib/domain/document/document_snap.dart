class DocumentSnap {
  const DocumentSnap({
    required this.id,
    required this.documentId,
    required this.name,
    required this.versionNumber,
    required this.document,
    required this.jsonDocument,
    required this.source,
    required this.changeSummary,
    required this.createdAt,
  });

  final int id;
  final int documentId;
  final String name;
  final int versionNumber;
  final String document;
  final Map<String, dynamic> jsonDocument;
  final String source;
  final String changeSummary;
  final DateTime createdAt;
}
