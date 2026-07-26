# `nx_offline` implementation plan

## Objective

Create one reusable `nx_offline` Flutter package that extracts the proven
offline patterns from `nx_notes` and supports future offline access in
`nx_time`, `nx_expense`, and other KGQL-backed Nexus applications.

Implementation proceeds through independently tested phases. A phase is
complete only when its interfaces, deterministic tests, failure behavior, and
documented acceptance gate are complete.

## Delivery principles

1. Define ports and values before concrete adapters.
2. Keep the synchronization core pure Dart.
3. Build deterministic memory fakes before Drift or KGQL implementations.
4. Run the same contract suite against memory and production adapters.
5. Never migrate an application feature until restart and failure tests cover
   its local-first path.
6. Do not claim guarantees that the current KGQL backend cannot provide.
7. Migrate one vertical workflow at a time rather than replacing an entire app
   at once.

## Implementation checkpoint — 2026-07-26

The standalone package foundation is implemented:

- Phase 0 package scaffold, public barrel, dependency rules, and architecture
  tests.
- Phase 1 identity, revision, cursor, entity, mutation, remote-change, failure,
  conflict, and status values.
- Phase 2 synchronization ports, deterministic retry, and outbox coalescing.
- Phase 3 push-before-pull coordinator, leases, concurrent-run collapse,
  collection cursors, failure handling, and conflict handoff.
- Phase 4 Drift reference database and store with atomic local entity/outbox
  writes, account isolation, retries, cursor persistence, conflicts, and
  close/reopen tests.
- Phase 5 schema-aware KGQL transport boundary and explicit compatibility
  capability reporting. Model-specific KGQL codecs remain application-owned.
- Phase 7 cached-session storage/restoration, HTTP probing, logout policy,
  Flutter lifecycle triggers, and sync-status UI.

The package passes its unit, persistence, restart, layering, session, transport,
and widget tests with a clean analyzer run. Phase 6 requires KGQL backend work.
Phases 8 onward are intentionally not started: no production application uses
the package yet.

## Phase 0: Package scaffold and dependency rules

### Deliverables

- Create `nx_offline/pubspec.yaml` as a local Flutter package.
- Add `lib/nx_offline.dart` with an initially minimal public API.
- Create the `core`, `sync`, `storage`, `kgql`, `session`, and `flutter`
  directories described in `architecture.md`.
- Add formatting, linting, and test configuration consistent with the other
  Nexus packages.
- Add architecture tests enforcing internal dependency rules.
- Add `nx_offline` as a path dependency only to a test consumer initially.

### Acceptance gate

- `flutter analyze` passes.
- The package test suite runs independently.
- Architecture tests fail when a forbidden dependency is introduced.
- No production application behavior has changed.

## Phase 1: Core synchronization vocabulary

### Deliverables

- `AccountScope`.
- `EntityKey` with stable local identity and optional remote ID.
- Opaque `Revision` and `SyncCursor`.
- `PendingMutation` and mutation types.
- `MutationReceipt`.
- `RemoteRecord`, `RemoteTombstone`, and `RemoteChangePage`.
- `SyncFailure`, retryability rules, and authentication classification.
- `SyncConflict` and `SyncStatus`.
- Validation and equality semantics for every value.

### Tests

- Invalid IDs and account scopes are rejected.
- Assigning a remote ID preserves local identity.
- Revisions and cursors remain opaque.
- Pending mutation eligibility respects retry time and lease expiry.
- Failure classification is deterministic.
- Values serialize and deserialize without loss where persistence requires it.

### Acceptance gate

- All values are pure Dart.
- No Flutter, Drift, Riverpod, GraphQL, KGQL, or `nx_db` imports exist in
  `core`.

## Phase 2: Policies and synchronization ports

### Deliverables

- `SyncStore` interface.
- `SyncTransport` interface.
- `SyncCollectionAdapter` interface.
- Outbox coalescing policy.
- Exponential retry policy with a configurable cap.
- Pull/conflict decision policy.
- Clock and ID-generator ports.
- Deterministic memory implementations for tests.

### Tests

- Multiple updates retain the oldest stable operation ID and newest payload.
- Create followed by update remains a create.
- Create followed by delete produces no remote mutation.
- Delete and update combinations follow explicit rules.
- Retry delays are deterministic with an injected clock.
- Conflicting account or entity operations cannot coalesce.

### Acceptance gate

- Policies are independently unit tested.
- Ports expose no Drift, KGQL, Flutter, or application domain types.

## Phase 3: Shared sync coordinator

### Deliverables

- Push-before-pull synchronization coordinator.
- Concurrent-run collapse.
- Durable operation claims with leases.
- Retry and non-retryable failure handling.
- Authentication blocking.
- Per-collection pull and cursor processing.
- Conflict handoff to collection adapters.
- Observable sync status.

### Tests

- Creates, updates, and deletes are pushed successfully.
- A transient failure schedules a retry without losing work.
- One failed entity does not block an unrelated entity.
- Authentication failure stops the run before pull.
- Concurrent triggers return the same active run.
- An expired claim can be recovered by another worker.
- A cursor advances only after the adapter imports a complete page.
- Conflicts preserve local and remote records.
- Multiple collections maintain independent cursors.

### Acceptance gate

- The complete coordinator runs headlessly with memory adapters.
- Tests use no Flutter bindings or live network.

## Phase 4: Drift synchronization storage

### Deliverables

- Shared Drift tables for outbox, cursors, conflicts, and metadata.
- Mapper between Drift rows and core values.
- Atomic claim, complete, fail, and cursor operations.
- Reusable migration helpers.
- A transaction API allowing an application projection update and outbox
  mutation to commit together.
- Database filename and account-partition helpers.

### Contract tests

Run one shared store contract against memory and Drift implementations:

- Atomic projection/outbox write.
- No partial write on validation failure.
- One pending mutation per entity when coalescing is enabled.
- Concurrent workers cannot claim one operation.
- Retry and lease metadata persist.
- Completion assigns remote identity and revision atomically.
- Cursors and conflicts persist.
- Account partitions cannot leak.

### Restart tests

- Pending work survives database close and reopen.
- Expired leases recover after reopen.
- Conflict records survive reopen.
- Schema migration retains existing pending work.

### Acceptance gate

- The Drift adapter passes the same behavioral contract as the memory adapter.
- Generated files are reproducible.
- Database migrations are covered by upgrade tests.

## Phase 5: KGQL compatibility transport

### Purpose

Provide an adapter for the current KGQL APIs while explicitly representing the
guarantees the backend does and does not yet provide.

### Deliverables

- Serializable versioned KGQL mutation envelope.
- KGQL push adapter for create, update, delete, tags, and relations supported
  by existing APIs.
- Collection pull adapter using explicit model-type registration.
- Error translation into `SyncFailure` categories.
- Compatibility capability flags for idempotency, atomic revisions,
  tombstones, and cursors.
- Deterministic fake KGQL transport.

### Tests

- Mutation payloads preserve every supported KGQL field.
- Transport errors classify as transient.
- 401/403 classify as authentication failures.
- Validation errors do not retry forever.
- Model types route to the correct collection.
- Current compatibility polling does not overwrite dirty local records.

### Acceptance gate

- The adapter is usable for read hydration and existing-entity updates.
- Documentation clearly states that process-local idempotency, read-then-write
  revision checks, timestamp cursors, and missing tombstones are not full
  production guarantees.

## Phase 6: KGQL server synchronization contract

### Backend deliverables

- Durable mutation idempotency keys.
- Atomic expected-revision validation and mutation.
- Client entity ID support or durable create-operation association.
- Opaque committed revisions.
- Incremental changes by model type.
- Durable opaque cursors.
- Deletion tombstones.
- Idempotent relation mutation behavior.

### Client deliverables

- Production KGQL sync transport using the new endpoints.
- Capability negotiation or a versioned protocol.
- Removal of process-local idempotency emulation from the production path.
- Lost-response and concurrent-update integration tests.

### Acceptance gate

- Replaying a create after a lost response cannot duplicate a KGQL model.
- Two concurrent conditional updates cannot both commit from the same base
  revision.
- A remote deletion reliably removes a clean local projection.
- Pull resumes from a cursor without missing or duplicating changes.

This phase is the server prerequisite for claiming complete synchronization
correctness. Client work may proceed earlier using the compatibility adapter.

## Phase 7: Session and Flutter lifecycle modules

### Deliverables

- Cached-session store interface and preferences adapter.
- Session restorer distinguishing reachable, unreachable, and unauthorized.
- Explicit logout retention/erase policy.
- Riverpod composition helpers.
- Synchronization triggers on coordinator creation, app resume, restored
  connectivity, and manual refresh.
- Observable status provider and compact status/retry widget.

### Tests

- Cached account opens when the backend is unreachable.
- Timeout retains the cached account.
- Definite authorization rejection clears the cached session.
- Logout erases only the selected account partition when requested.
- Lifecycle triggers do not create concurrent sync runs.
- Connectivity events request sync but do not assert backend reachability.
- Status UI exposes saved-local, syncing, retrying, blocked, and conflict
  states accessibly.

### Acceptance gate

- A small test application can launch offline, show local data, and retry sync
  without application-specific lifecycle code.

## Phase 8: Extract and migrate `nx_notes`

### Purpose

Use `nx_notes` as the first production consumer and preserve its existing
offline behavior while replacing duplicated infrastructure.

### Deliverables

- Move or adapt core sync values, policies, retry, leases, and session logic
  into `nx_offline`.
- Keep Notes domain entities and document projections in `nx_notes`.
- Implement a Notes collection adapter.
- Migrate Notes Riverpod composition to shared lifecycle components.
- Route all document mutations through the offline-first repository, including
  create, delete, pinned state, tags, and supported relations.
- Render shared sync status in the editor or application chrome.

### Tests

- Existing `nx_notes` offline tests remain green.
- Online and offline feature tests exercise the same repository path.
- Full library and document bodies survive restart.
- Existing document edits survive force-quit and synchronize later.
- Delete no longer leaves a clean cached document visible.
- Offline-created Notes entities use `EntityKey` until a remote ID is assigned.

### Acceptance gate

- `nx_notes` contains no duplicate generic sync coordinator or retry logic.
- Feature code does not call the remote repository for offline-capable
  operations.
- No user-visible regression in online or offline navigation.

## Phase 9: `nx_time` daily-log vertical slice

### Purpose

Prove that `nx_offline` supports a second application and a different KGQL
model type before expanding the shared abstraction.

### Deliverables

- Time-owned daily-log Drift projection.
- Daily-log local queries indexed by logged date/time.
- Daily-log KGQL codec and collection adapter.
- Offline-first `LogRepository` implementation.
- Configurable hydration window.
- Offline create, edit, delete, and restart behavior.

### Tests

- Local calendar-day queries match KGQL fixtures across time-zone boundaries.
- A new log can be created without a remote ID.
- Edits and deletes survive restart.
- Sync assigns remote identity without changing local identity.
- Conflicts preserve both log versions.
- Online and offline day views use the same repository stream.

### Acceptance gate

- The daily-log workflow works through airplane-mode restart and later
  convergence.
- No `nx_time` feature imports KGQL or Drift directly.

## Phase 10: `nx_time` actions and dependencies

### Deliverables

- Action projection with indexed start/end timestamps and model subtype.
- Offline overlap queries for day and week views.
- Action create, edit, delete, and child-relation mutations.
- Referenced task and project hydration.
- Separate collection cursors for actions, tasks, projects, and goals.
- Subscription events imported through the same collection adapters as pull.

### Tests

- Overnight and boundary-overlapping actions match existing query semantics.
- Parent/child operations respect dependency ordering.
- Required referenced entities remain available outside the normal time window.
- Subscription and pull delivery are idempotent.

### Acceptance gate

- Today, calendar, and action-detail screens remain usable offline for the
  hydrated window.

## Phase 11: `nx_expense` list and form vertical slice

### Deliverables

- Expense-owned Drift projection with indexed date, amount, currency, and
  inclusion flags.
- Local tags and relation representation required by list/detail screens.
- Expense KGQL codec and collection adapter.
- Offline-first `ExpenseRepository` list, get, upsert, minimal create, and
  delete operations.
- Expense/product-line local unit of work.
- Configurable history hydration policy.

### Tests

- Expense mapping round trips all attributes, tags, products, and relations.
- Date-range and filter results match KGQL fixture results.
- Create, update, and delete survive restart.
- Expense and product-line updates commit atomically locally.
- Conflicts preserve amount, date, product, tag, and relation variants.

### Acceptance gate

- The expense list, detail, and form work offline for hydrated data.
- Online and offline screens use the same local repository queries.

## Phase 12: Local expense aggregates

### Deliverables

- Local equivalents for count, total, spending by day, tag system, and
  relation.
- Cache-coverage metadata indicating the downloaded date range.
- Dashboard behavior for complete and partial local history.
- Query performance indexes and benchmarks.

### Tests

- Local aggregates match KGQL aggregate fixtures.
- Ignored and excluded expenses follow existing rules.
- Partial-history dashboards communicate their coverage.
- Updates immediately change local aggregates before synchronization.

### Acceptance gate

- The primary expense dashboard is useful offline and accurately describes
  incomplete coverage when applicable.

## Phase 13: Relations, Teller data, and assets

Treat these as independent capabilities so one cannot destabilize the core
expense workflow.

### Relations

- Queue idempotent relation links and unlinks.
- Support dependencies on offline-created entities.
- Preserve relation conflicts explicitly.

### Teller

- Keep bank synchronization online-only.
- Cache previously downloaded Teller transactions read-only.
- Queue expense-to-Teller links only when the backend contract supports
  idempotent timeline relations.

### Assets

- Add content-addressed local asset identity.
- Store receipt/image bytes separately from model projections.
- Add a durable upload outbox and reference-rewrite acknowledgement.
- Keep incomplete imports isolated from visible records.

### Acceptance gate

- Each capability has its own store contract, restart tests, and failure UI.
- The base expense workflow remains functional when any optional capability is
  unavailable.

## Phase 14: Adoption guidance for additional apps

### Deliverables

- A concise integration guide.
- A sample collection adapter and projection.
- Generator or templates for common test fixtures only if repeated manual work
  justifies them.
- A capability checklist for declaring read, create, update, delete,
  relations, assets, aggregates, and publishing offline-ready.

### Acceptance gate

- A new KGQL model type can be added without modifying the sync coordinator,
  shared Drift outbox behavior, or Flutter lifecycle module.

## Shared quality gates

Every phase maintains:

- `dart format` with no changes.
- `flutter analyze` with no issues.
- Unit and contract tests passing.
- No hidden live-backend mutation in default tests.
- Deterministic clocks and IDs in synchronization tests.
- Database restart coverage for every durable workflow.
- Architecture boundary tests.
- Documentation updated when interfaces or guarantees change.

## Recommended first milestone

The first useful implementation milestone ends after Phase 9:

1. Shared package scaffold.
2. Core values, policies, coordinator, and Drift storage.
3. Current KGQL compatibility adapter.
4. Session and Flutter lifecycle integration.
5. `nx_notes` migration.
6. `nx_time` daily-log vertical slice.

Completing a second application is the proof that the shared interfaces are
genuinely reusable. Avoid generalizing further based only on `nx_notes`.

## Known blockers and dependencies

Full synchronization guarantees depend on KGQL providing:

- Durable idempotency keys.
- Atomic expected-revision mutation.
- Stable client identity for offline creates.
- Incremental model change cursors.
- Deletion tombstones.
- Idempotent relation mutations.

Without those features, local durability and offline reading/editing remain
valuable, but duplicate-create recovery, concurrent-write correctness, and
remote deletion reconciliation are necessarily limited.
