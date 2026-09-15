/// Why synchronization was requested.
///
/// The lifecycle layer reports intent only. Applications decide whether a
/// reason should upload an outbox, reconcile a library, or do both.
enum SyncReason {
  manual,
  foregroundDemand,
  appStarted,
  appResumed,
  connectivityRestored,
  timer,
}
