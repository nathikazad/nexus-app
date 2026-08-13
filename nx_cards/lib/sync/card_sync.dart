enum CardLocalSyncState { synced, queued, retryWaiting, blocked }

enum CardMutationStatus { applied, stale, deleted }

final class CardMutationResult {
  const CardMutationResult({
    required this.status,
    required this.entityId,
    this.updatedAt,
  });

  final CardMutationStatus status;
  final int entityId;
  final DateTime? updatedAt;
}
