import '../core/sync_models.dart';

final class RetryPolicy {
  const RetryPolicy({
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
  });

  final Duration baseDelay;
  final Duration maxDelay;

  DateTime retryAt(DateTime now, int attempt) {
    if (attempt < 1) {
      throw ArgumentError.value(attempt, 'attempt', 'must be at least 1');
    }
    final shift = attempt - 1 > 30 ? 30 : attempt - 1;
    final multiplier = 1 << shift;
    final milliseconds = baseDelay.inMilliseconds * multiplier;
    final capped = milliseconds > maxDelay.inMilliseconds
        ? maxDelay.inMilliseconds
        : milliseconds;
    return now.add(Duration(milliseconds: capped));
  }
}

final class OutboxCoalescer {
  const OutboxCoalescer();

  PendingMutation? coalesce(
    PendingMutation existing,
    PendingMutation incoming,
  ) {
    _validate(existing, incoming);
    if (existing.type == MutationType.relation ||
        incoming.type == MutationType.relation) {
      if (existing.type != incoming.type) {
        throw StateError(
          'relation and entity mutations require separate aggregate keys',
        );
      }
      return existing.copyWith(payload: incoming.payload);
    }
    return switch ((existing.type, incoming.type)) {
      (MutationType.create, MutationType.update) => existing.copyWith(
        payload: incoming.payload,
      ),
      (MutationType.create, MutationType.delete) => null,
      (MutationType.create, MutationType.create) => existing.copyWith(
        payload: incoming.payload,
      ),
      (MutationType.update, MutationType.update) => existing.copyWith(
        payload: incoming.payload,
      ),
      (MutationType.update, MutationType.delete) => existing.copyWith(
        type: MutationType.delete,
        payload: incoming.payload,
      ),
      (MutationType.update, MutationType.create) => existing.copyWith(
        payload: incoming.payload,
      ),
      (MutationType.delete, MutationType.create) ||
      (MutationType.delete, MutationType.update) => existing.copyWith(
        type: MutationType.update,
        payload: incoming.payload,
      ),
      (MutationType.delete, MutationType.delete) => existing.copyWith(
        payload: incoming.payload,
      ),
      _ => throw StateError('unsupported mutation combination'),
    };
  }

  void _validate(PendingMutation existing, PendingMutation incoming) {
    if (existing.account != incoming.account ||
        existing.collection != incoming.collection ||
        existing.entityKey.localId != incoming.entityKey.localId) {
      throw StateError('mutations must target the same account and entity');
    }
  }
}
