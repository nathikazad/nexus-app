# Shared automatic freshness

`AppSyncLifecycle` checks on startup, resume, reconnection, subscription hints,
and a foreground recovery timer. `AppStateCoordinator` coalesces wakeups, retains
changes received during a pull, and retries failures with backoff.

`AppSyncSession` compares root and collection hashes, requests only changed
manifests and bodies, verifies the advertised revision, and rejects incomplete
batches. It does not own files or local edits. `nx_offline` owns reconciliation,
pending mutations and integrity repair; `nx_data` owns live view caches.

A subscription is a hint to check authoritative state, not a data payload or a
trusted checkpoint. No successful refresh checkpoint is recorded after a failed
read. Screen loading never waits for initial worker publication.
