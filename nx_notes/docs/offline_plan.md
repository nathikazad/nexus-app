# `nx_notes` offline-first implementation plan

## Purpose

Add dependable offline writing to the macOS version of `nx_notes`, while
building the capability as a collection of small, layer-oriented modules.
Each module must have a documented interface and comprehensive tests before it
is connected to another production module.

The first target is macOS. The domain, application, synchronization, and
contract-test code must remain platform-neutral so it can later be reused by
the web, iOS, and Android applications.

## Implementation checkpoints

### Phases 0-3 complete — 2026-07-20

- Added application-layer boundaries and transitional architecture tests.
- Added pure document identity, revision, operation, failure, conflict, and
  sync-state values.
- Added deterministic outbox coalescing, retry, conflict, and pull-resolution
  policies.
- Added the `LocalNotesStore` port, reusable contract suite, and memory adapter.
- Verified 70 non-integration tests and a clean `flutter analyze` run.

### Phases 4-7 complete — 2026-07-20

- Added the Drift database, document mapper, and `LocalNotesStore` adapter with
  durable documents, outbox leases, cursor metadata, and conflict snapshots.
- Ran the reusable local-store contract against both memory and Drift adapters,
  including database restart and uniqueness tests.
- Added the `RemoteDocumentGateway` port, reusable contract suite, deterministic
  fake, and KGQL adapter.
- Added a platform-neutral synchronization engine with push-before-pull,
  exponential retry, conditional updates, conflict preservation, authentication
  blocking, and concurrent-run collapse.
- Covered lost responses after server commit and engine reconstruction to prove
  that retry uses stable operation identities without duplicate creates.
- Verified 105 non-integration tests and a clean `flutter analyze` run.
- Known server prerequisite: the existing KGQL repository does not yet expose
  durable idempotency keys, atomic revision preconditions, tombstones, or an
  incremental change cursor. The KGQL adapter can only emulate those guarantees
  inside one process until the backend contract is extended.

### Phases 8-11 implementation checkpoint — 2026-07-20

- Connected the sync engine to Drift and the fake remote, then verified offline
  restart, expired-lease recovery, post-commit replay, durable conflicts, and a
  bounded 100-document queue.
- Connected the sync engine to the KGQL adapter with memory and Drift stores,
  verifying create/update flow, initial reconciliation, and account partitioning
  through a deterministic repository test double.
- Generated the macOS Flutter target with the `com.nexus.nxnotes` application
  identity, sandboxed network/file entitlements, and desktop window defaults.
- Verified 112 non-integration tests, a clean `flutter analyze` run, and a
  successful release build at `Nexus Notes.app`.
- Phase 8 and phase 11 gates are complete. The live-backend portions of phases 9
  and 10 remain gated on server-provided durable idempotency, atomic revision
  preconditions, deletion reconciliation, and a real change cursor. The local
  integration paths are complete and no live Nexus records were mutated.

## Delivery principle

Development proceeds through gated phases:

1. Define one building block and its public contract.
2. Implement a deterministic fake or in-memory version.
3. Test the contract, success cases, failure cases, and recovery behavior.
4. Implement the production adapter where applicable.
5. Run the same contract suite against the fake and production adapter.
6. Record that the phase gate is satisfied.
7. Only then connect the building block to modules from earlier phases.

No phase is complete merely because its happy path works. A phase is complete
when its acceptance checks, failure tests, and dependency-boundary tests pass.

## Initial product scope

The first usable offline release supports:

- launching on macOS without a connection after a prior authenticated session;
- reading locally downloaded documents;
- editing existing documents without a connection;
- persisting every draft locally across quit, crash, sleep, and restart;
- showing whether work is local, queued, syncing, synced, failed, or conflicted;
- synchronizing safely when Nexus becomes reachable; and
- preserving both versions when local and remote content conflict.

Offline document creation, images, links, snapshots, deletion, and publishing
are deliberately added in later gated phases. Durable editing of existing text
documents is the first vertical product milestone.

## Non-goals for the first milestone

- Collaborative real-time editing.
- Automatic block-level or character-level conflict merging.
- Background synchronization while the Mac application is not running.
- Offline publishing or mirror generation.
- Replacing KGQL as the server-side system of record.
- Adding web service-worker or IndexedDB support during the Mac milestone.

## Layered architecture

The existing `core`, `domain`, `data`, and `features` structure remains the
foundation. Add an `application` layer for use cases and orchestration, and a
small `composition` area for Riverpod wiring.

```text
lib/
  core/          generic Flutter utilities
  domain/        pure entities, values, and rules
  application/   ports, use cases, and synchronization orchestration
  data/          Drift, KGQL, filesystem, preferences, and HTTP adapters
  features/      Flutter presentation and interaction
  composition/   construction of concrete adapters and Riverpod providers
```

Dependency direction:

```text
domain
  ^
  |
application
  ^          ^
  |          |
data      features
   \        /
    composition
```

Rules:

- `domain/` is pure Dart and imports no higher layer.
- `application/` imports only `domain/` and pure Dart packages.
- `data/` implements application ports and may import `application/` and
  `domain/`, but never `features/`.
- `features/` imports `application/`, `domain/`, and `core/`, but never concrete
  `data/` adapters.
- `composition/` is the only production code that constructs and connects
  concrete adapters.
- Public interfaces must not expose Drift, SQLite, GraphQL, KGQL, Riverpod,
  Flutter, HTTP, or filesystem implementation types.

## Target directory structure

```text
lib/
  domain/
    document/
      document.dart
      document_identity.dart
      document_publish.dart
      document_query.dart
      document_result_context.dart
      document_snap.dart
    sync/
      document_revision.dart
      pending_operation.dart
      sync_conflict.dart
      sync_state.dart
      sync_status.dart
    assets/
      document_asset.dart
    links/
      linked_model.dart
    tags/
      tag_system.dart

  application/
    ports/
      local_notes_store.dart
      remote_document_gateway.dart
      document_asset_store.dart
      session_store.dart
      connectivity_probe.dart
      clock.dart
      id_generator.dart
    documents/
      offline_notes_service.dart
      create_document.dart
      save_document.dart
      delete_document.dart
      query_documents.dart
    sync/
      document_sync_engine.dart
      conflict_detector.dart
      outbox_coalescer.dart
      retry_policy.dart
    session/
      restore_offline_session.dart

  data/
    local/
      drift/
        notes_database.dart
        tables/
          documents_table.dart
          snapshots_table.dart
          outbox_table.dart
          assets_table.dart
          sync_metadata_table.dart
        daos/
          documents_dao.dart
          outbox_dao.dart
          assets_dao.dart
        drift_document_mapper.dart
        drift_local_notes_store.dart
      memory/
        memory_local_notes_store.dart
    remote/
      kgql/
        kgql_remote_document_gateway.dart
        kgql_document_mapper.dart
        document_attr_keys.dart
        document_schema_loader.dart
    assets/
      mac_file_asset_store.dart
      nexus_asset_gateway.dart
    session/
      preferences_session_store.dart
    connectivity/
      nexus_connectivity_probe.dart
    support/
      system_clock.dart
      uuid_generator.dart

  features/
    auth/
    desktop/
    document/
    editor/
    mobile/
    navigator/
    shell/
    sync_status/
      sync_status_indicator.dart
      sync_details_sheet.dart
      storage_settings_view.dart

  composition/
    application_providers.dart
    data_providers.dart
    platform_providers.dart
```

Tests mirror the production layers:

```text
test/
  domain/
  application/
  data/
    local/drift/
    local/memory/
    remote/kgql/
    assets/
    session/
  features/
  support/
    contracts/
    fakes/
  integration/
  layering/
```

## Core contracts

The signatures below are directional. Exact Dart names may be refined during
the contract phase, but responsibilities must remain separated.

### Local notes store

The local store is the durable source used by the UI.

```dart
abstract interface class LocalNotesStore {
  Stream<List<LocalDocument>> watchDocuments(DocumentQuery query);
  Stream<LocalDocument?> watchDocument(DocumentKey key);
  Future<LocalDocument?> getDocument(DocumentKey key);

  Future<void> importRemoteDocuments(List<RemoteDocument> documents);

  Future<void> saveDraftAndEnqueue(
    LocalDocument document, {
    required PendingOperation operation,
  });

  Future<PendingOperation?> claimNextOperation({
    required String workerId,
    required Duration lease,
  });

  Future<void> completeOperation(
    String operationId, {
    required RemoteWriteResult result,
  });

  Future<void> failOperation(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  });
}
```

`saveDraftAndEnqueue` is intentionally atomic. The local document and its
outbox entry must be written in one SQLite transaction. Separating them into
independent production transactions could lose a change during a crash.

### Remote document gateway

```dart
abstract interface class RemoteDocumentGateway {
  Future<RemoteChangeSet> pullChanges({required String? cursor});

  Future<RemoteWriteResult> createDocument(
    RemoteCreateRequest request, {
    required String idempotencyKey,
  });

  Future<RemoteWriteResult> updateDocument(
    RemoteUpdateRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  });
}
```

The interface exposes synchronization semantics, not GraphQL or KGQL types.

### Synchronization engine

```dart
abstract interface class DocumentSyncEngine {
  Stream<SyncStatus> watchStatus();

  Future<SyncRunResult> synchronize({
    SyncReason reason = SyncReason.automatic,
  });
}
```

The implementation depends only on ports, a clock, an ID generator, and pure
sync policies. It must not import Flutter, Riverpod, Drift, or GraphQL.

### Feature-facing service

```dart
abstract interface class OfflineNotesService {
  Stream<List<LocalDocument>> watchRecent();
  Stream<LocalDocument?> watchDocument(DocumentKey key);
  Future<void> saveDraft(LocalDocument document);
  Future<void> synchronize();
}
```

The editor uses this interface instead of a KGQL repository or data provider.

## Local database model

Initial Drift tables:

### `local_documents`

```text
local_id                 TEXT PRIMARY KEY
remote_id                INTEGER NULL UNIQUE
account_key              TEXT NOT NULL
model_type               TEXT NOT NULL
title                    TEXT NOT NULL
plain_text               TEXT NOT NULL
json_document            TEXT NOT NULL
metadata_json            TEXT NOT NULL
local_updated_at         DATETIME NOT NULL
server_updated_at        DATETIME NULL
base_server_updated_at   DATETIME NULL
sync_state               TEXT NOT NULL
deleted_locally          BOOLEAN NOT NULL
```

### `sync_outbox`

```text
operation_id       TEXT PRIMARY KEY
account_key        TEXT NOT NULL
aggregate_id       TEXT NOT NULL
operation          TEXT NOT NULL
payload_json       TEXT NOT NULL
base_revision      TEXT NULL
status             TEXT NOT NULL
attempt_count      INTEGER NOT NULL
next_attempt_at    DATETIME NULL
lease_owner        TEXT NULL
lease_expires_at   DATETIME NULL
last_error         TEXT NULL
created_at         DATETIME NOT NULL
```

All locally persisted records are partitioned by both user and backend preset.

## Definition of a completed building block

A module is ready to connect only when it has:

- a documented, minimal public interface;
- typed inputs, results, and errors;
- no imports that violate dependency rules;
- deterministic control of time and generated IDs where relevant;
- an in-memory or fake implementation where useful;
- reusable contract tests for every adapter implementation;
- success, failure, cancellation, and recovery tests;
- tests for restart persistence where it owns durable state;
- no production dependency on another unproven phase; and
- a short phase-completion note recording commands and results.

## Phased implementation

### Phase 0: Architecture and test harness

Goal: establish rules before implementing offline behavior.

Build:

- Add `application/` and `composition/` directories.
- Document layer responsibilities and import rules.
- Add test helpers for fake clocks and deterministic IDs.
- Establish a convention for reusable adapter contract suites.
- Add a phase-completion checklist template.

Test independently:

- Extend layering tests to reject Flutter in `application/`.
- Reject `data/` imports from `features/`.
- Reject `features/` imports from `data/`.
- Reject Drift outside `data/local/drift/`.
- Reject KGQL and GraphQL outside `data/remote/kgql/` and composition.
- Reject Riverpod outside features and composition, allowing a documented
  transition period for existing providers.

Gate:

- All existing tests pass.
- Every new layering test is green.
- No offline production behavior has been added.

### Phase 1: Domain offline vocabulary

Goal: define pure values and state transitions.

Build:

- `DocumentKey` with a stable local UUID and optional remote integer ID.
- `RemoteRevision`.
- `PendingOperation` and operation types.
- `DocumentSyncState` and `SyncStatus`.
- `SyncConflict` and typed sync failures.
- Pure state-transition validation.

Test independently:

- Equality and serialization-neutral behavior.
- Legal and illegal sync-state transitions.
- Assigning a remote ID without changing local identity.
- Conflict value preservation.
- Operation ordering and identity.
- Account-key isolation values.

Gate:

- Pure Dart tests pass without Flutter test bindings.
- Domain imports no application, data, Flutter, Riverpod, or `nx_db` code.

### Phase 2: Pure synchronization policies

Goal: prove decisions before adding storage or networking.

Build:

- Outbox coalescing policy.
- Retry and exponential-backoff policy.
- Conflict detector.
- Pull-versus-local resolution policy.
- Operation ordering rules.

Test independently:

- Hundreds of edits coalesce to one latest-state update.
- Create remains ordered before update or delete.
- Retry delays and maximum delays are deterministic.
- Transient, authentication, validation, and conflict failures are classified.
- Local dirty content is never overwritten by a remote pull.
- Equal revisions do not create false conflicts.

Gate:

- Policy tests cover a written decision table.
- Tests use fake time and contain no timers or real network calls.

### Phase 3: Local-store contract and memory adapter

Goal: finalize local persistence behavior before choosing SQLite details.

Build:

- `LocalNotesStore` application port.
- Reusable `local_notes_store_contract.dart` suite.
- `MemoryLocalNotesStore` reference implementation.
- Atomic save-and-enqueue semantics in the interface.
- Operation leases and completion/failure behavior.

Test independently:

- Document create, update, query, and observation.
- Save and outbox enqueue are atomic.
- Repeated saves coalesce correctly.
- Only one worker can claim an operation.
- Expired leases become claimable.
- Completing and failing operations update the correct state.
- Account partitions remain isolated.
- Observers receive changes in a defined order.

Gate:

- The memory adapter passes every local-store contract test.
- Sync orchestration has not yet been connected.

### Phase 4: Drift local adapter

Goal: implement durable local behavior behind the proven contract.

Build:

- Drift database and initial migration.
- Documents and outbox tables.
- DAOs that expose Drift row types only inside the adapter.
- Drift-to-domain mappers.
- `DriftLocalNotesStore`.
- Temporary-database test factory.

Test independently:

- Run the complete Phase 3 contract against Drift.
- Document JSON round-trips without loss.
- Save and enqueue use a single transaction.
- Database close/reopen preserves documents and queued work.
- Interrupted or failed transactions persist neither partial write.
- Migrations preserve existing fixtures.
- Unique constraints enforce identity and account rules.
- Concurrent reads and writes remain consistent.

Gate:

- Memory and Drift adapters pass the same contract suite.
- Restart and migration tests pass using real SQLite files.
- No feature or remote code is connected.

### Phase 5: Remote-gateway contract and fake adapter

Goal: define server interaction without GraphQL details.

Build:

- `RemoteDocumentGateway` application port.
- Typed remote requests, results, change sets, and errors.
- Reusable remote-gateway contract suite.
- Configurable `FakeRemoteDocumentGateway`.

Test independently:

- Idempotent create and update semantics.
- Conditional revision checks.
- Change cursor advancement.
- Deleted-record tombstones.
- Timeouts before and after simulated server application.
- Authentication, validation, conflict, and transient errors.

Gate:

- Fake gateway passes the remote contract.
- Tests can deterministically simulate every failure class needed by sync.

### Phase 6: KGQL remote adapter

Goal: isolate existing KGQL behavior behind the remote contract.

Build:

- Move or adapt KGQL mapping into `data/remote/kgql/`.
- Implement `KgqlRemoteDocumentGateway`.
- Keep GraphQL request construction inside this adapter.
- Add any required backend request fields for revision and idempotency.

Test independently:

- Run applicable remote contract cases against a mocked GraphQL client.
- Verify exact requests and response mapping.
- Verify malformed responses become typed errors.
- Verify transport and GraphQL errors are classified correctly.
- Add environment-gated live-backend contract tests.

Backend prerequisite:

- Server creates must accept a stable client document ID or idempotency key.
- Updates must accept an expected revision and reject stale writes.
- Replayed operations must not duplicate effects.
- A change feed or defined full-reconciliation response must include deletions.

Gate:

- Mocked adapter tests pass.
- Backend contract tests prove idempotency and stale-write rejection.
- The adapter still has not been connected to the editor.

### Phase 7: Synchronization engine with memory and fake modules

Goal: prove the complete algorithm without SQLite, GraphQL, Flutter, or
Riverpod.

Build:

- `DocumentSyncEngine` implementation.
- Push loop, pull loop, operation claiming, and status stream.
- Injected clock, ID generator, local store, remote gateway, and retry policy.

Test independently:

- Push one edit successfully.
- Pull a new or updated remote document.
- Repeated synchronization is idempotent.
- Timeout before server application retries safely.
- Timeout after server application retries without duplication.
- Restart is simulated by creating a new engine over retained memory state.
- One failed document does not block unrelated documents.
- Local and remote changes produce a conflict containing both versions.
- Authentication failure pauses work without deleting it.
- Concurrent sync requests collapse into one run.
- Cancellation releases or expires claimed operations safely.

Gate:

- Full failure matrix passes using only the memory store and fake gateway.
- Sync engine imports no Flutter, Riverpod, Drift, GraphQL, or KGQL libraries.

### Phase 8: Cross-module persistence integration

Goal: connect the proven sync engine to real Drift while keeping the remote
side fake.

Connect:

```text
DocumentSyncEngine + DriftLocalNotesStore + FakeRemoteDocumentGateway
```

Test integration:

- Save offline, terminate the store and engine, reopen, and sync.
- Terminate during a claimed operation and recover after lease expiry.
- Simulate server-applied/client-timeout and restart before retry.
- Preserve a conflict across database restart.
- Process a large bounded queue without unbounded memory growth.

Gate:

- All persistence failure-injection tests pass.
- No UI or real backend is involved.

### Phase 9: Cross-module remote integration

Goal: prove backend semantics independently of Drift.

Connect:

```text
DocumentSyncEngine + MemoryLocalNotesStore + KgqlRemoteDocumentGateway
```

Test integration:

- Create and update against a test backend.
- Replay identical operation IDs.
- Reject stale revisions.
- Pull changes from a cursor or full reconciliation.
- Observe remote deletion.
- Recover from backend restart or temporary unavailability.

Gate:

- Environment-gated backend integration tests pass repeatedly.
- No macOS or editor code is involved.

### Phase 10: Full headless integration

Goal: connect real persistence and real remote transport before UI adoption.

Connect:

```text
DocumentSyncEngine + DriftLocalNotesStore + KgqlRemoteDocumentGateway
```

Test integration:

- Import remote documents into an empty local database.
- Edit locally, restart, reconnect, and sync.
- Update the same document remotely and locally to verify conflict handling.
- Confirm server and local revisions converge after successful sync.
- Verify account and backend-preset partitions.

Gate:

- The headless offline system passes without Riverpod or Flutter widgets.
- Diagnostic output identifies every failed operation without logging document
  contents.

### Phase 11: macOS platform scaffold

Goal: establish a working Mac application without changing editor persistence.

Build:

- Add the `macos/` Flutter target.
- Configure application identity, signing, network entitlements, and icons.
- Verify AppFlowy Editor, file picker, keyboard commands, window sizing, and
  existing conditional imports.

Test independently:

- `flutter build macos` succeeds.
- Existing online login and document editing work.
- Existing test suites remain green.
- Platform smoke tests cover launch and basic editor interaction.

Gate:

- Packaged application runs online with no offline module connected to UI.

### Phase 12: Offline session module

Goal: allow cached local data to open when Nexus is unreachable.

Build:

- Session-store port and preferences adapter.
- Offline session restoration use case.
- Distinguish offline reachability from authentication rejection.
- Keep local databases partitioned by account and backend preset.

Test independently:

- Cached session restores without a network.
- Timeout does not clear credentials.
- Definite authorization rejection requires login.
- Logout behavior explicitly retains or erases downloaded data.
- No account can open another account's local partition.

Gate:

- Session contract tests pass before router integration.

### Phase 13: Feature-facing service and Riverpod composition

Goal: expose one stable application API to features.

Build:

- `OfflineNotesService` implementation.
- Composition providers for local store, gateway, sync engine, clock, and IDs.
- Feature tests using memory/fake module overrides.

Test integration:

- Features receive local records before remote refresh completes.
- Saving through the facade returns after the local transaction.
- Provider disposal does not discard pending work.
- Fake modules can replace every production adapter in widget tests.

Gate:

- Features can use the facade without importing `data/`.
- Composition is the only layer constructing concrete adapters.

### Phase 14: Existing-document editor integration

Goal: deliver the first usable offline writing milestone.

Build:

- Replace editor save scheduling with `OfflineNotesService.saveDraft`.
- Read documents from the local store.
- Import remote documents into local storage during refresh.
- Flush editor state on document switch, window close, and app lifecycle changes.
- Add compact sync-state presentation.

Test thoroughly:

- Edit offline and force-quit immediately.
- Relaunch offline and recover the latest draft.
- Sleep and wake while offline.
- Reconnect and synchronize.
- Lose the response after the server applies an update.
- Introduce a second-device conflict and preserve both versions.
- Verify title and body changes share the same durability guarantees.

Gate:

- No editor path writes directly to KGQL.
- No network failure can remove a locally saved draft or queued operation.
- macOS acceptance matrix passes.

This is the first product release candidate.

### Phase 15: Offline document creation

Goal: create documents without a server-assigned integer ID.

Build:

- Use stable local UUID identity throughout tabs, caches, and routes.
- Make remote integer ID optional until first sync.
- Add or backfill a backend `client_id` where required.
- Resolve existing remote URLs to local identity.

Test thoroughly:

- Create, edit, restart, and reopen entirely offline.
- First sync assigns a remote ID without changing the active tab or route.
- Retry after a lost create response does not duplicate the document.
- Internal references survive identity assignment.

Gate:

- Offline-created documents synchronize idempotently.

### Phase 16: Local snapshots, tags, and deletion

Goal: expand offline document operations in independent sub-phases.

Order:

1. Local snapshots.
2. Tags and pinned state.
3. Recoverable local deletion and server tombstones.

Each sub-phase defines its own port additions, contract cases, adapter tests,
sync-policy tests, and integration gate before the next begins.

### Phase 17: Offline assets

Goal: add images after text synchronization is proven.

Build:

- `DocumentAssetStore` port.
- Memory asset adapter and reusable asset-store contract.
- Mac filesystem adapter with content hashing and atomic writes.
- Stable `nxasset://<uuid>` references.
- Asset upload queue and remote URL mapping.

Test independently before integration:

- Import, read, attach, delete, and deduplicate assets.
- Crash during import leaves no corrupt visible asset.
- Restart preserves local references.
- Retried upload does not duplicate remote files.
- Unsynced assets are never pruned.

Gate:

- Memory and Mac adapters pass the same contract.
- Editor integration occurs only after asset sync tests pass headlessly.

### Phase 18: Links and publishing

Goal: add remaining network-heavy behavior without weakening core durability.

- Queue links only when both endpoints can be resolved remotely.
- Preserve unresolved local links until dependent creates finish.
- Keep publishing explicitly online-only initially.
- Consider queued publishing only after publish operations have idempotency and
  revision semantics.

Each capability is a separate building block with its own contract and gate.

### Phase 19: Web adapter reuse

Goal: reuse proven modules rather than create a second offline architecture.

Reuse unchanged:

- domain values;
- application ports and use cases;
- synchronization engine and policies;
- remote KGQL gateway;
- contract suites and failure matrix.

Replace or add:

- Drift WASM/IndexedDB or OPFS database connection;
- browser asset storage adapter;
- browser lifecycle adapter;
- service-worker app-shell caching;
- multi-tab coordination and outbox claiming safeguards.

Run the same local-store and asset-store contracts against the web adapters
before connecting them to the web UI.

## Sync status presented to the user

The UI should use domain/application status values and contain no transport
logic. Initial labels:

```text
Saved locally
Offline - 3 changes waiting
Syncing
Synced just now
Sync failed - retry
Conflict requires attention
```

The editor remains usable during retryable failures.

## Test commands and phase evidence

Each phase should document its exact commands in the implementation commit.
Expected categories include:

```sh
dart test <pure module tests>
flutter test <adapter or widget tests>
flutter analyze
flutter build macos
```

Live backend tests remain opt-in through a named environment flag so normal
local and CI runs never mutate Nexus unintentionally.

For every phase, record:

```text
Phase:
Interfaces added or changed:
Implementations tested:
Contract suites executed:
Failure cases executed:
Migration or restart cases executed:
Commands and results:
Known limitations deferred to later phases:
```

## First implementation sequence

The immediate work order is:

```text
0  architecture and test harness
1  domain offline vocabulary
2  pure synchronization policies
3  local-store contract and memory adapter
4  Drift local adapter
5  remote-gateway contract and fake adapter
6  KGQL remote adapter and backend guarantees
7  synchronization engine using memory/fake modules
8  sync engine + real Drift + fake remote
9  sync engine + memory store + real KGQL
10 complete headless integration
11 macOS platform scaffold
12 offline session module
13 feature-facing service and composition
14 existing-document editor integration
```

This ordering intentionally delays UI integration. It ensures that when the
editor is connected, local durability, retries, idempotency, conflict handling,
and restart recovery have already been proven independently.
