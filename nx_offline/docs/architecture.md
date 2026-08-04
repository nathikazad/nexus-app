# nx_offline architecture

## The short version

`nx_offline` contains reusable offline mechanics. Each application keeps its
own typed domain model, Drift database, KGQL calls, merge rules, and pull
protocol.

The boundary is deliberate:

> The application owns what its data means. `nx_offline` owns how durable work
> is claimed, retried, scheduled, coordinated, and triggered.

This lets Nx Notes synchronize documents by content hash while a future Nx
Expense implementation can synchronize date partitions. Neither policy is
forced into a universal JSON repository.

## Supported platforms

The package supports native Flutter applications. Nx Notes enables it on iOS
and macOS and does not construct any offline services on web. Web continues to
read and write KGQL directly.

## Ownership

### nx_offline owns

- Stable account identity: application + logical server + user.
- Route-independent cached sessions.
- Durable outbox values and the `OutboxStore` interface.
- Mutation-handler routing by collection.
- Operation claims, leases, retry classification, exponential backoff, and one
  persistent retry wake-up.
- Observable synchronization status.
- Coordination between full and keyed reconciliation requests.
- Startup, resume, and restored-connectivity lifecycle triggers.
- A shared Drift outbox schema and persistence adapter for app-owned databases.

### Each application owns

- Domain entities and typed local tables.
- The application database and its schema version.
- The transaction that writes a domain change and its outbox row atomically.
- KGQL queries, structs, mutations, model types, and attribute mapping.
- Mutation payload codecs and server response mapping.
- Full and targeted pull protocols.
- Hash, cursor, or date-partition semantics.
- Conflict decisions and local projection updates.
- Riverpod composition and platform policy.

`nx_offline` does not import `nx_notes`, `nx_expense`, `nx_time`, `nx_main`, or
`nx_db`.

## Public libraries

```text
package:nx_offline/nx_offline.dart
  Stable model, session, lifecycle, outbox, retry, and reconciliation APIs.

package:nx_offline/nx_offline_drift.dart
  Optional Drift table declarations plus DriftOutboxPersistence.
```

The stable library does not export a database implementation. An application
embeds the shared tables in the same database as its typed domain tables. This
is what makes a local domain write and its outbox operation one physical
transaction.

## Current source structure

```text
nx_offline/lib/
  nx_offline.dart
  nx_offline_drift.dart
  src/
    core/sync_models.dart
    outbox/
      outbox_processor.dart
      retry_scheduler.dart
    reconciliation/reconciliation_coordinator.dart
    session/
      cached_session.dart
      session_restorer.dart
    flutter/offline_lifecycle.dart
    persistence/drift/
      offline_tables.dart
      drift_outbox_persistence.dart
    sync/
      policies.dart
      sync_ports.dart
```

There is intentionally no generic entity database, generic KGQL transport, or
push-before-pull mega-coordinator.

## Stable account identity

```dart
const account = AccountIdentity(
  application: 'nx_notes',
  serverId: 'nexus-primary',
  userId: '1',
);
```

`serverId` names the logical database, not an address. LAN, WAN, and Tailscale
presets are routes to the same server and therefore produce the same account.
Changing a route cannot select a different cache or outbox.

Nx Notes retains its historical physical partition name, `user:<id>`, so an
installed application continues to open the existing `nx_notes_user_<id>`
database. This is an application compatibility detail, not part of shared
identity semantics.

## Local write and upload flow

```text
user command
  -> application repository transaction
       -> update typed domain row
       -> insert/coalesce outbox row
  -> UI observes local row immediately
  -> OutboxProcessor claims durable operation
  -> application MutationHandler performs model-specific KGQL call
  -> application OutboxStore adapter commits receipt or failure
```

The UI never waits for the remote mutation before treating the edit as saved
locally. A process kill after the transaction cannot lose the queued operation.

`OutboxProcessor` is single-flight. It routes operations to a handler by
collection, validates receipts, persists retries, blocks non-retryable work,
and arms `RetryScheduler` at the earliest durable retry timestamp.

## Pull and reconciliation flow

Pull semantics remain application-owned. The shared
`ReconciliationCoordinator<K, V>` only coordinates concurrency:

- Concurrent full requests share one full run.
- Concurrent requests for the same key share one keyed run.
- A keyed request arriving during a full run waits and reads the new local
  state instead of issuing duplicate network work.
- A full request waits for keyed work that was already running.
- If a full request fails, a waiting keyed request may attempt its narrower
  reconciliation.

For Nx Notes, `K` is a document ID and the full request is a document hash
manifest. For Nx Expense, `K` can be a UTC day and the full request can compare
date-level summaries.

## Session and lifecycle flow

`OfflineSessionRestorer` distinguishes three outcomes:

- reachable: open the cached account online;
- unreachable: retain credentials and open the cached account offline;
- unauthorized: clear the cached session and require login.

`OfflineLifecycle` reports `appStarted`, `appResumed`, and
`connectivityRestored` to one application callback. It does not treat a network
interface as proof that the backend is reachable, and it absorbs background
errors so lifecycle callbacks cannot produce unhandled futures.

Applications pass `null` to disable lifecycle synchronization. Nx Notes does
this on web.

## Drift integration

An application imports `nx_offline_drift.dart`, creates the shared schema from
its database `onCreate`, and delegates the generic outbox operations to
`DriftOutboxPersistence`. Its repository implements `OutboxStore` by composing
that adapter with its typed domain tables.

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (migrator) async {
    await migrator.createAll();
    await DriftOutboxPersistence.createSchema(this);
  },
);
```

The exported table declarations remain useful when an application's Drift
generator can discover dependency tables. The persistence adapter is the
portable path: Drift does not reliably generate accessors for Dart table
declarations from another package in every build layout.

The package does not own migrations. The application owns its database schema
and migration path because only the application can atomically coordinate its
domain tables with the shared outbox tables.

## Failure behavior

- `transient` and `unknown` failures retry with bounded exponential backoff.
- `authentication`, `conflict`, and `validation` failures become blocked.
- Blocked operations never become eligible merely because time passed.
- Claims have leases, so abandoned work can be recovered after lease expiry.
- The operation ID is stable across retries.
- Application handlers decide how a stale remote write changes the local
  projection.

## Riverpod boundary

Riverpod constructs and disposes long-lived objects. It does not implement
sync loops or data propagation.

Providers should expose stable callback and stream instances. Manufacturing a
new lifecycle callback during every widget build makes it look like a new sync
target and can cause repeated refreshes.

## Reuse checklist for another application

1. Define its typed local schema and repositories.
2. Create the shared Drift schema and compose `DriftOutboxPersistence`.
3. Commit each local edit and outbox operation in one transaction.
4. Implement `OutboxStore` over the application database.
5. Implement one `MutationHandler` per remote collection.
6. Define full and keyed pull functions using the application's natural
   partition or manifest.
7. Wrap them in `ReconciliationCoordinator`.
8. Compose the processor, sessions, and lifecycle in Riverpod for native only.
9. Test restart, offline reads, retry, stale writes, account isolation, and
   overlapping reconciliation requests.

The Expense reuse test in `test/reuse/expense_domain_example_test.dart` is a
small executable example of this boundary.
