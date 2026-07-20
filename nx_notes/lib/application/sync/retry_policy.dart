class RetryPolicy {
  const RetryPolicy({
    this.initialDelay = const Duration(seconds: 2),
    this.maximumDelay = const Duration(minutes: 5),
  });

  final Duration initialDelay;
  final Duration maximumDelay;

  Duration delayForAttempt(int attempt) {
    if (attempt < 1) {
      throw ArgumentError.value(attempt, 'attempt', 'must be at least one');
    }
    var delay = initialDelay.inMilliseconds;
    for (var index = 1; index < attempt; index++) {
      if (delay >= maximumDelay.inMilliseconds) return maximumDelay;
      delay *= 2;
    }
    return Duration(milliseconds: delay.clamp(0, maximumDelay.inMilliseconds));
  }

  DateTime retryAt(DateTime now, int attempt) =>
      now.add(delayForAttempt(attempt));
}
