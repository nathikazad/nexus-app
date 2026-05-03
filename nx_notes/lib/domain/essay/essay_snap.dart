class EssaySnap {
  const EssaySnap({
    required this.id,
    required this.essayId,
    required this.versionNumber,
    required this.document,
    required this.jsonDocument,
    required this.source,
    required this.changeSummary,
    required this.createdAt,
  });

  final int id;
  final int essayId;
  final int versionNumber;
  final String document;
  final Map<String, dynamic> jsonDocument;
  final String source;
  final String changeSummary;
  final DateTime createdAt;
}
