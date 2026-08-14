# nx_offline

Shared offline persistence and KGQL synchronization foundations for Nexus
Flutter applications.

The package currently provides:

- Pure-Dart identity, revision, mutation, failure, conflict, cursor, and status
  values.
- Outbox coalescing and retry policies.
- An account-scoped sync supervisor that serializes pulls, batches keyed
  demand, collapses lifecycle/manual triggers, and runs durable uploads first.
- Embeddable Drift outbox tables for atomic domain writes, leases, retries,
  and conflicts.
- Cached-session restoration, preferences persistence, HTTP probing, and
  explicit logout data-retention policy.
- Flutter startup, resume, connectivity, and sync-status components.

Applications continue to own their domain repositories, optimized projection
tables, KGQL codecs, hydration rules, and conflict policies. They implement
`MutationHandler` and `PullReconciler<K>` and compose them with
`OutboxProcessor` and `SyncSupervisor<K>`.

## Status

The package is used by `nx_docs` and `nx_cards`; other applications can supply
their own typed stores, mutation handlers, and pull reconcilers.

The current KGQL compatibility boundary cannot itself provide durable server
idempotency, atomic revision preconditions, deletion tombstones, or a true
incremental cursor. See [architecture.md](docs/architecture.md) and
[plan.md](docs/plan.md).

## Verification

```sh
flutter pub get
dart run build_runner build
dart format --set-exit-if-changed lib test
flutter test
flutter analyze
```
