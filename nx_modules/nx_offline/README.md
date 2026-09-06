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
- Immutable native content files, a thin SQLite index, atomic catalog
  publication and generation-safe local pending state.

Applications continue to own their domain repositories, optimized projection
tables, KGQL codecs, hydration rules, and conflict policies. They implement
`MutationHandler` and `PullReconciler<K>` and compose them with
`OutboxProcessor` and `SyncSupervisor<K>`.

## Status

The package is used by `nx_docs`, `nx_cards`, `nx_books` and `nx_expense`.
Start with [Offline storage: follow one document](docs/file_storage.md) for the
file/index implementation, app adapters, migration story and current boundaries.

The current KGQL compatibility boundary cannot itself provide durable server
idempotency, atomic revision preconditions, deletion tombstones, or a true
incremental cursor. See [architecture.md](docs/architecture.md) and
[plan.md](docs/plan.md).

## Verification

The file-content / SQLite-index migration has a separate
[acceptance test specification](docs/file_storage_test_spec.md). It defines
shared storage contracts, application-specific checks, interruption recovery,
scaling assertions, and Android performance gates. Implemented checks and
remaining release gates are distinguished in [file_storage.md](docs/file_storage.md).

```sh
flutter pub get
dart run build_runner build
dart format --set-exit-if-changed lib test
flutter test
flutter analyze
```
