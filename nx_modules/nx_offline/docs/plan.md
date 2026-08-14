# nx_offline implementation record

## Objective

Extract reusable offline mechanics from Nx Docs without turning document
semantics into a generic framework. Migrate Nx Docs incrementally, validating
each phase before starting the next one.

## Completed phases

### Phase 1: characterization

- Preserved native cached-first, full-library, per-document, retry, and restart
  behavior with tests.
- Added explicit coverage for Books and concurrent library synchronization.

Gate: the original Nx Docs suite passed before production changes began.

### Phase 2: identity and public boundary

- Added route-independent `AccountIdentity`.
- Added shared cached-session values and storage.
- Split the stable API from optional Drift declarations.

Gate: LAN, WAN, and Tailscale map to one account; layering tests pass.

### Phase 3: embeddable persistence

- Added embeddable outbox, metadata, and conflict Drift tables.
- Added `OutboxStore`.
- Proved an application row and outbox row commit or roll back in one physical
  Drift transaction.

Gate: persistence and UTC retry behavior pass independently.

### Phase 4: durable delivery runtime

- Added `OutboxProcessor` and `RetryScheduler`.
- Added handler routing, leasing, single-flight processing, retries, blocked
  status, and status streams.
- Made non-retryable operations durably blocked.

Gate: success, concurrency, retry wake-up, and blocked-work tests pass.

### Phase 5: Nx Docs upload migration

- Added a Notes `OutboxStore` adapter and document mutation handler.
- Replaced the Notes upload loop with a thin facade over `OutboxProcessor`.
- Preserved create, update, delete, stale-write, retry, and on-disk behavior.

Gate: focused upload tests and the complete Nx Docs suite pass.

### Phase 6: session and lifecycle migration

- Delegated Notes session restoration and HTTP probing to shared policy.
- Replaced the Notes lifecycle observer with `OfflineLifecycle`.
- Made lifecycle callbacks and connectivity streams provider-stable.
- Preserved historical preference keys and `user:<id>` database names.
- Kept all offline construction disabled on web.

Gate: startup, resume, connectivity, web isolation, offline restart, cache
compatibility, and complete suites pass.

### Phase 7: reconciliation coordination

- Added `ReconciliationCoordinator<K, V>`.
- Migrated full library and per-document Notes reconciliation to it.
- Prevented overlapping equivalent full/document requests.

Gate: both overlap directions, same-key single-flight, fallback, and complete
suites pass.

### Phase 8: one architectural story

- Removed the unused generic entity database, generic KGQL transport,
  `SyncCoordinator`, cursor/change-page model, and their legacy-only tests.
- Narrowed `nx_offline.dart` to stable mechanics.
- Kept `nx_offline_drift.dart` limited to embeddable table declarations.

Gate: no application referenced removed APIs; Nx Docs and nx_offline passed
their complete suites and analyzers.

### Phase 9: independent reuse proof

- Added a fake Expense domain with an Expense-specific mutation handler.
- Used the shared processor for per-expense delivery.
- Used date keys with the shared reconciliation coordinator.
- Enforced that shared production code imports no Nexus application.

Gate: the Expense proof and the complete nx_offline suite pass.

### Phase 10: documentation and final verification

- Updated Nx Docs and nx_offline documents to match the implemented code.
- Audited the diff, public exports, generated sources, and unchanged cache
  identity.
- Ran formatting, package analyzers, package tests, and repository diff checks.

### Phase 11: account-scoped sync supervision

- Replaced keyed concurrent reconciliation with `SyncSupervisor<K>`.
- Enforced one active pull per account and batched different keys.
- Migrated Nx Docs and Nexus Cards lifecycle/manual synchronization.
- Made Nx Docs sessions local-only and catalogs local projections.

## Resulting public story

```text
application-owned typed database
  + application-owned OutboxStore adapter
  + application-owned MutationHandler
  + application-owned full/keyed pull functions
  + nx_offline OutboxProcessor
  + nx_offline SyncSupervisor
  + nx_offline session/lifecycle policy
```

There are no server changes in this refactor. Nx Docs continues to use its
existing `mutateDocument` and `syncDocuments` protocol.
