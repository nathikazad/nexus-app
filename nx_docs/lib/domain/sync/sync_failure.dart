enum SyncFailureKind {
  transient,
  authentication,
  validation,
  conflict,
  cancelled,
  unknown,
}

class SyncFailure {
  const SyncFailure({required this.kind, required this.message});

  final SyncFailureKind kind;
  final String message;

  bool get isRetryable =>
      kind == SyncFailureKind.transient || kind == SyncFailureKind.unknown;
}
