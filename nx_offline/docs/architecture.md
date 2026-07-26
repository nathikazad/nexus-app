# `nx_offline` architecture

## Purpose

`nx_offline` is the shared offline foundation for Nexus Flutter applications.
It provides durable local writes, synchronization, retry, conflict preservation,
cached-session restoration, and Flutter lifecycle integration for applications
whose remote system of record is KGQL.

The package is intended for `nx_notes`, `nx_time`, `nx_expense`, and future
Nexus applications. It reuses synchronization mechanics without moving
application-specific domain models or business rules into a generic framework.

The central rule is:

> Features read and write through an application repository backed by local
> durable storage. Only the synchronization worker communicates with KGQL.

An explicitly online-only capability may bypass this rule only when its public
interface and user-facing behavior make that requirement clear.

## Goals

- Make local persistence the normal application path online and offline.
- Commit an optimistic local change and its pending remote mutation atomically.
- Preserve pending work across process termination, crashes, and restarts.
- Reuse synchronization, retry, leasing, session, and lifecycle code across
  applications.
- Keep application domain models, queries, projections, and conflict decisions
  inside their owning applications.
- Maintain clean interfaces that are testable without widgets or a live backend.
- Support multiple KGQL model types and relations within one application.
- Keep every local database partitioned by backend and account.

## Non-goals

- A universal repository that replaces application domain repositories.
- A generic JSON query engine for all application screens.
- Sharing one physical SQLite database between installed applications.
- Hiding capabilities that genuinely require a network connection.
- Automatic field-level or collaborative conflict merging.
- Treating connectivity detection as proof that the KGQL backend is reachable.

## Package boundary

The repository contains one shared package:

```text
nx_db       Low-level KGQL client, requests, schemas, and authentication
nx_offline  Shared offline storage, synchronization, KGQL transport, and Flutter integration
nx_notes    Notes domain, local projections, codecs, queries, and policies
nx_time     Time domain, local projections, codecs, queries, and policies
nx_expense  Expense domain, local projections, codecs, queries, and policies
```

`nx_offline` may depend on `nx_db`, Drift, Flutter, and Riverpod. Its internal
core and synchronization modules remain pure Dart even though the package as a
whole is a Flutter package.

## Internal structure

```text
nx_offline/
  lib/
    nx_offline.dart
    src/
      core/
        account_scope.dart
        entity_key.dart
        revision.dart
        pending_mutation.dart
        mutation_receipt.dart
        remote_change.dart
        sync_cursor.dart
        sync_status.dart
        sync_failure.dart
        sync_conflict.dart
      sync/
        sync_coordinator.dart
        sync_store.dart
        sync_transport.dart
        sync_collection_adapter.dart
        retry_policy.dart
        outbox_coalescer.dart
        conflict_policy.dart
      storage/
        drift_sync_store.dart
        sync_database.dart
        migrations/
        tables/
      kgql/
        kgql_sync_transport.dart
        kgql_mutation.dart
        kgql_remote_record.dart
      session/
        cached_session.dart
        session_store.dart
        session_restorer.dart
      flutter/
        offline_lifecycle.dart
        offline_providers.dart
        sync_status_view.dart
  test/
    contracts/
    core/
    sync/
    storage/
    kgql/
    session/
    flutter/
```

Only stable values and interfaces are exported from `nx_offline.dart`.
Generated Drift types, table definitions, mapper helpers, and other
implementation details remain private.

## Dependency rules

Internal imports follow these rules:

```text
core
  ^
  |
sync
  ^       ^
  |       |
storage  kgql
    \     /
     session
        ^
        |
     flutter
```

- `core/` imports only Dart libraries.
- `sync/` imports `core/` and Dart libraries.
- `storage/` imports `core/`, `sync/`, and Drift.
- `kgql/` imports `core/`, `sync/`, and `nx_db` KGQL APIs.
- `session/` imports the smallest interfaces required for session probing and
  persistence.
- `flutter/` composes the other modules with Flutter and Riverpod.
- `nx_offline` never imports an application package.
- Application features never import concrete `nx_offline/src/storage` or
  `nx_offline/src/kgql` implementations directly; composition code constructs
  them.

Architecture tests enforce these rules.

## Runtime data flow

```text
Feature / view model
        |
        v
Application repository
        |
        +---- watch/read ----> application-owned local projection
        |
        +---- command -------> atomic local projection + outbox transaction
                                      |
                                      v
                              shared sync coordinator
                                      |
                           push pending mutations first
                                      |
                                      v
                               KGQL sync transport
                                      |
                           pull changes and tombstones
                                      |
                                      v
                         application collection adapters
                                      |
                                      v
                         application-owned local projection
```

The UI observes local database streams. Remote changes become visible only
after they are imported into the local projection. Therefore online and offline
screens use the same data path and render the same states.

## Core values

### Account scope

Every stored row and synchronization operation belongs to an `AccountScope`:

```dart
final class AccountScope {
  const AccountScope({
    required this.backend,
    required this.userId,
    required this.application,
  });

  final String backend;
  final String userId;
  final String application;
}
```

The scope prevents data leakage between production, development, accounts, and
applications. Physical databases are also separated by application and
account, providing defense in depth.

### Entity identity

Every locally writable entity has a permanent client-generated identity and an
optional KGQL model ID:

```dart
final class EntityKey {
  const EntityKey({required this.localId, this.remoteId});

  final String localId;
  final int? remoteId;
}
```

The local ID does not change when synchronization assigns a remote ID. Routes
and relationships that must support offline-created entities use `EntityKey`
instead of assuming an integer server ID exists.

### Revision

`Revision` is an opaque server-provided value. Clients compare revisions but do
not derive ordering or meaning from their contents.

### Pending mutation

A pending mutation contains:

- A stable operation ID used as the server idempotency key.
- Account scope and collection name.
- Target entity key.
- Mutation type: create, update, delete, or relation mutation.
- A versioned serialized KGQL mutation payload.
- An optional expected remote revision.
- Creation time, retry attempt, lease, and error metadata.
- An optional operation-group or dependency ID for composite workflows.

The operation ID survives retries and process restarts.

## Public synchronization interfaces

The shared coordinator works with durable synchronization records, not
application domain entities.

```dart
abstract interface class SyncStore {
  Future<PendingMutation?> claimNext({
    required AccountScope account,
    required String workerId,
    required DateTime now,
    required Duration lease,
  });

  Future<void> complete(
    String operationId,
    MutationReceipt receipt,
  );

  Future<void> fail(
    String operationId,
    SyncFailure failure,
    DateTime retryAt,
  );

  Future<SyncCursor?> readCursor(
    AccountScope account,
    String collection,
  );

  Future<void> writeCursor(
    AccountScope account,
    String collection,
    SyncCursor cursor,
  );
}

abstract interface class SyncTransport {
  Future<MutationReceipt> push(PendingMutation mutation);

  Future<RemoteChangePage> pull({
    required AccountScope account,
    required String collection,
    required Set<String> modelTypes,
    required SyncCursor? cursor,
  });
}

abstract interface class SyncCollectionAdapter {
  String get collectionName;
  Set<String> get modelTypes;

  Future<void> applyRemote(RemoteRecord record);
  Future<void> applyTombstone(RemoteTombstone tombstone);
  Future<void> acknowledgeMutation(MutationReceipt receipt);
  Future<void> preserveConflict(RemoteRecord remote);
}
```

The exact Dart signatures may evolve during implementation, but these
responsibilities remain separate.

## Local persistence

Each application owns a Drift database containing application projection
tables plus the shared synchronization tables.

```text
application projection tables
sync_outbox
sync_cursors
sync_conflicts
sync_metadata
optional asset_uploads
```

Example physical database names:

```text
nx_notes_production_user123.sqlite
nx_time_production_user123.sqlite
nx_expense_production_user123.sqlite
```

Application-specific projections are preferred over a universal JSON table:

- `nx_time` needs indexed start/end timestamps, dates, status, and project
  relationships.
- `nx_expense` needs indexed dates, amounts, currencies, flags, tags, and
  relation IDs for local filtering and aggregates.
- `nx_notes` needs full document bodies, titles, tags, and updated timestamps.

Raw KGQL payloads may be retained for diagnostics or forward compatibility,
but they are not the only query representation.

## Local transaction rule

Every offline-capable command commits its optimistic projection change and
outbox mutation in one database transaction:

```text
begin transaction
  validate account and entity identity
  update application projection
  coalesce or insert pending mutation
commit transaction
```

If the transaction fails, neither the visible local change nor its remote
mutation remains. Once it commits, the application may safely report that the
change is saved locally.

## Synchronization algorithm

One synchronization run performs the following steps:

1. Collapse concurrent triggers onto the active run.
2. Claim the oldest eligible outbox mutation with a time-limited lease.
3. Push the mutation using its stable idempotency key and expected revision.
4. Atomically acknowledge success in the local database.
5. On a retryable failure, persist exponential-backoff metadata and release
   the lease.
6. On an authentication failure, stop the run and report a blocked state.
7. Continue processing unrelated mutations after non-authentication failures.
8. Pull each registered collection from its durable cursor.
9. Apply remote records, tombstones, and conflicts through its collection
   adapter.
10. Advance a cursor only after the corresponding remote page is durably
    imported.

Push occurs before pull so the server observes local work before the client
reconciles incoming changes.

## KGQL server contract

Safe reusable synchronization requires two backend capabilities.

### Atomic idempotent mutation

Conceptually:

```text
mutateKgql(
  idempotencyKey,
  expectedRevision,
  clientEntityId,
  mutation
) -> remoteId, revision
```

Required guarantees:

- Replaying an idempotency key returns the original result without applying a
  second mutation.
- Expected-revision validation and mutation occur atomically.
- A create accepts a client entity ID or otherwise durably associates the
  idempotency key with the created KGQL model.
- The committed record returns an opaque revision.

### Incremental change feed

Conceptually:

```text
kgqlChanges(modelTypes, cursor) -> records, tombstones, nextCursor
```

The feed returns model type, model ID, revision, payload, deletion state, and a
stable cursor position. Tombstones are required because a record that simply
disappears from `listAll` cannot remove an existing local cache entry.

Until these server guarantees exist, the package may provide explicitly named
compatibility adapters, but they must document duplicate-create, revision-race,
and deletion-reconciliation limitations.

## Conflict handling

The shared layer detects and preserves conflicts. Each application decides how
to resolve them.

- Clean local records may be replaced by a newer remote revision.
- Dirty local records remain when the incoming revision equals their base
  revision.
- Divergent dirty and remote revisions create a durable conflict containing
  both versions.
- No version is silently discarded.
- Automatic merge policies must be explicit and model-specific.

Examples:

- Notes may present local and remote document bodies.
- Time may treat new daily logs as append-only but require review for a
  concurrently changed action interval.
- Expense may require review when amount, date, products, or relations diverge.

## Hydration policies

Each collection defines how much remote data should be downloaded.

- Notes can hydrate the complete document library.
- Time can hydrate a rolling date window plus referenced tasks, projects, and
  all locally modified records.
- Expense can hydrate a configurable history window or the complete expense
  ledger, depending on size and dashboard requirements.

Hydration policy is independent of synchronization correctness. Pending local
work and records required by local relationships are never evicted merely
because they fall outside the normal window.

## Session and logout behavior

Cached-session restoration distinguishes:

- Backend reachable and session accepted: online session.
- Backend unreachable or timed out: offline session using the cached account.
- Definite authentication rejection: clear the cached session and require
  login.

Logout makes downloaded-data handling explicit:

- Retain the account partition for future offline access.
- Erase only the active account partition.

Network failure never implies authentication rejection.

## Flutter integration

The Flutter module supplies:

- Riverpod providers for the active account, store, transport, coordinator, and
  registered collections.
- Synchronization triggers on service creation, app resume, restored
  connectivity, and explicit refresh.
- Observable sync status for UI.
- Small reusable status and retry controls.

Connectivity events are hints to attempt synchronization. A network interface
being available does not mean the backend is reachable.

Features do not branch between online and offline repositories. They observe
the same local streams in both states.

## Application integration

An application supplies:

- Domain repository interfaces.
- Offline-first repository implementations.
- Drift projection tables and queries.
- Domain-to-local and KGQL-to-domain codecs.
- `SyncCollectionAdapter` implementations.
- Hydration and conflict policies.
- Explicit online-only capability policies.

Example composition:

```dart
final coordinator = SyncCoordinator(
  store: syncStore,
  transport: KgqlSyncTransport(client),
  collections: <SyncCollectionAdapter>[
    ActionSyncAdapter(database),
    DailyLogSyncAdapter(database),
    TaskSyncAdapter(database),
  ],
);
```

## Testing strategy

### Shared contract suites

`nx_offline` publishes reusable tests for every store and transport adapter:

- Projection change and outbox mutation commit atomically.
- Cross-account writes are rejected without partial state.
- Repeated updates coalesce predictably.
- Create followed by delete has no unintended remote effect.
- Two workers cannot claim the same operation.
- Expired leases recover after restart.
- Retry state survives restart.
- A remote import cannot overwrite dirty local state.
- Cursors advance only after durable import.
- Tombstones remove clean records and preserve dirty conflicts.
- Concurrent synchronization triggers share one run.
- A lost response followed by retry does not duplicate a create when the
  backend contract supports idempotency.

### Application tests

Each application tests:

- Domain model to local row round trips.
- Domain command to KGQL mutation mapping.
- Remote KGQL record to domain projection mapping.
- Local query results against equivalent KGQL fixture queries.
- Application-specific conflict decisions.
- Date, time-zone, aggregate, tag, and relation behavior.

### Restart integration tests

Every offline workflow follows this reusable scenario:

1. Hydrate online.
2. Close and reopen the database without a remote connection.
3. Read and mutate locally.
4. Close and reopen again.
5. Restore the remote connection.
6. Synchronize.
7. Verify local and remote convergence.

Widget tests prove that important screens render the same local data path
online and offline.

## Architecture decisions

- Use one package with enforced internal modules rather than several small
  packages.
- Reuse synchronization mechanics, not application domain repositories.
- Use app-specific projection tables rather than only generic JSON storage.
- Use one physical database per application and account.
- Treat stable local identity as fundamental, not temporary.
- Require atomic local projection/outbox transactions.
- Require backend idempotency, atomic revisions, tombstones, and cursors for
  full production guarantees.
- Keep online-only capabilities explicit.
- Prefer contract tests and deterministic fakes before production adapters.
