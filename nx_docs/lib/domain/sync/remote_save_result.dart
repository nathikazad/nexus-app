enum RemoteSaveStatus { applied, stale }

final class RemoteSaveResult {
  const RemoteSaveResult({
    required this.status,
    required this.documentId,
    required this.updatedAt,
    this.serverHash,
  });

  final RemoteSaveStatus status;
  final int documentId;
  final DateTime updatedAt;
  final String? serverHash;
}
