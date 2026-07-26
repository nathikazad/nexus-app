# nx_offline

Shared offline persistence and KGQL synchronization foundations for Nexus
Flutter applications.

The package currently provides:

- Pure-Dart identity, revision, mutation, failure, conflict, cursor, and status
  values.
- Outbox coalescing and retry policies.
- A push-before-pull synchronization coordinator with durable leases,
  concurrent-run collapse, per-collection cursors, and conflict handoff.
- A Drift reference store with account-scoped local JSON entities, atomic
  entity/outbox writes, retries, cursors, and conflicts.
- A schema-aware KGQL transport boundary with explicit backend capability
  reporting.
- Cached-session restoration, preferences persistence, HTTP probing, and
  explicit logout data-retention policy.
- Flutter startup, resume, connectivity, and sync-status components.

Applications continue to own their domain repositories, optimized projection
tables, KGQL codecs, hydration rules, and conflict policies. They implement
`SyncCollectionAdapter` and use `SyncCoordinator` for shared synchronization.

## Status

The package foundation is implemented and tested independently. It is not yet
wired into `nx_notes`, `nx_time`, or `nx_expense`.

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
