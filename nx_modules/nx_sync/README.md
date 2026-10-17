# Shared automatic freshness

`AppSyncLifecycle` checks on startup, reconnection, and subscription hints.
On resume it checks only when more than five minutes have elapsed since the
last successful check (or no check has succeeded in this session). It has no
periodic polling timer. Apps opt in by wrapping their root with
`AppSyncLifecycle(synchronize: ..., remoteChanges: ..., child: ...)`;
`AppDataHost` already does this. The callback must complete after a successful
freshness check and throw on failure. A new callback/session resets freshness.

`AppStateCoordinator` coalesces wakeups, retains
changes received during a pull, and retries failures with backoff.

`AppSyncSession` compares root and collection hashes, requests only changed
manifests and bodies, verifies the advertised revision, and rejects incomplete
batches. It does not own files or local edits. `nx_offline` owns reconciliation,
pending mutations and integrity repair; `nx_data` owns live view caches.

A subscription is a hint to check authoritative state, not a data payload or a
trusted checkpoint. No successful refresh checkpoint is recorded after a failed
read. Screen loading never waits for initial worker publication.

On native platforms, `AppSyncSession` assembles app views, orders their data,
encodes JSON, and hashes it in a background isolate. Only snapshot data crosses
the isolate boundary; results are published on the calling isolate after
persistence succeeds. Web uses Flutter compute’s current-event-loop fallback.
