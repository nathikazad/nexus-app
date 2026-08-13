# Nexus Docs native offline refactor

## Status

Implemented and validated in phases through 2026-08-03.

The refactor separates reusable offline mechanics into `nx_offline` while
keeping all document semantics in Nexus Docs. It preserves installed native
caches and leaves the web application online-only.

## The architecture in one sentence

> Native reads and writes the typed local database first, then uses shared
> outbox and reconciliation mechanics to communicate through Notes-specific
> KGQL adapters; web talks to KGQL directly.

## Platform split

### iOS and macOS

- Open the cached session even when the backend is unreachable.
- Open the existing per-user Drift database.
- Render cached catalogs and documents immediately.
- Save edits and their outbox operation atomically.
- Upload pending edits in the background.
- Reconcile the full document library in the background.
- Hash-check an opened document without duplicating an active library request.

### Web

- Construct `WebNotesWorkspace`.
- Read and write KGQL directly.
- Do not open Drift.
- Do not construct an outbox, retry scheduler, or offline lifecycle callback.

The platform decision lives in composition, not in feature widgets.

## Main application interfaces

Presentation depends on four understandable interfaces:

- `NotesWorkspace`: catalogs, document sessions, create/delete, upload, and
  library sync.
- `DocumentSession`: one opened document and its refresh/edit state.
- `LocalNotesStore`: typed native projection and durable document outbox.
- `NotesRemoteApi`: Notes-specific catalog, document, mutation, and hash-sync
  operations.

Riverpod constructs these objects, selects native versus web implementations,
and disposes them. Business logic remains in plain Dart services.

## Native composition

```text
activeOfflineSessionProvider
  -> existing user:<id> partition
  -> NotesDatabase + DriftLocalNotesStore
  -> NotesOutboxStoreAdapter
  -> DocumentMutationHandler
  -> nx_offline OutboxProcessor
  -> BackgroundUploader compatibility facade
  -> DocumentSynchronizer
  -> NativeNotesWorkspace
```

`BackgroundUploader` no longer contains an upload loop. It preserves the
existing Notes-facing API while delegating claims, retries, scheduling, and
status to `OutboxProcessor`.

## Startup and lifecycle

`OfflineSyncLifecycle` is a small Riverpod wrapper around
`nx_offline.OfflineLifecycle`.

```text
application starts / resumes / connectivity returns
  -> stable lifecycle callback
  -> NativeNotesWorkspace.syncLibrary()
  -> upload pending edits
  -> compare local manifest with server
  -> apply changed documents and deletions locally
```

The callback is asynchronous and not awaited by application-shell rendering.
Cached data appears before the network request finishes. Provider-stable
callbacks and streams ensure widget rebuilds do not look like new startup
events and cannot create a refresh loop.

## Opening a document

```text
open document ID
  -> NativeDocumentSession reads local row
  -> cached full body is emitted immediately, if present
  -> DocumentSynchronizer requests keyed reconciliation
  -> pending edits upload first
  -> dirty local documents are not overwritten
  -> clean document ID + cached server hash go to syncDocuments
  -> changed body is stored and emitted
```

If the document is not cached, the same keyed request is foreground work. If
the device is offline, the session reports `unavailableOffline`.

The shared `ReconciliationCoordinator<int, LocalDocument?>` prevents duplicate
network work:

- two opens of the same ID share one request;
- two library triggers share one request;
- a document opened during library sync waits and reads the library result;
- a library sync requested during a document refresh waits for it, then runs.

## Editing and upload

```text
editor save
  -> LocalNotesStore.saveDraftAndEnqueue transaction
       -> update typed Documents row
       -> insert/coalesce PendingOperations row
  -> local stream updates the editor
  -> OutboxProcessor claims the operation
  -> DocumentMutationHandler calls NotesRemoteApi
  -> store adapter completes, retries, blocks, or imports stale remote data
```

The local transaction is the durability boundary. Killing the application
after it completes cannot remove the queued edit.

Document conflict semantics are still application-owned. The server accepts a
mutation only when the client `updated_at` is later. If the server reports the
operation stale, Nexus Docs fetches and imports the remote document and discards
the stale local operation. This matches the requirement to prefer later phone
edits over an old laptop edit that resumes later.

## Full library synchronization

Nexus Docs owns its hash protocol:

```text
local [{documentId, serverHash}]
  -> NotesRemoteApi.syncDocuments
  -> changed Documents and Books + deleted IDs
  -> one local applySyncBundle transaction
```

An empty manifest downloads every document. Later requests download only
changed content. A successful full run makes all returned Documents and Books
available offline. Hash computation and GraphQL/SQL model knowledge do not
exist in `nx_offline`.

"Sync now" and lifecycle synchronization use this same path. There is no
separate hard-fetch algorithm that downloads unchanged content.

## Sessions, accounts, and route changes

The logical identity is:

```text
application = nx_notes  # retained compatibility identity for nx_docs
server       = nexus-primary
user         = authenticated user ID
```

LAN, WAN, and Tailscale are routes to that same server. Changing the route does
not select a different cache.

Nexus Docs still reads and writes the original preference keys and still names
the physical partition `user:<id>`. Consequently this refactor does not make
an installed application appear empty or require a data migration.

An unreachable probe retains the session for offline use. Only a definite
401/403 clears it and requires login. Logout retains downloaded data unless an
explicit erase policy is chosen.

## Shared versus Notes-specific code

### Shared in nx_offline

- account and session identity;
- session restoration and HTTP probe mechanics;
- lifecycle events;
- outbox values and store interface;
- mutation processing, leasing, retry, wake scheduling, and status;
- full/keyed reconciliation coordination;
- embeddable Drift outbox/metadata/conflict declarations.

### Kept in Nexus Docs

- `NxDocument`, Books, catalogs, tags, and editor behavior;
- `NotesDatabase` and its migrations;
- atomic Notes row/outbox methods;
- document mutation payloads and stale-write handling;
- KGQL structs and GraphQL calls;
- document hashes, manifests, bundles, and deletion rules;
- Riverpod providers and native/web selection.

## Key files

```text
nx_docs/lib/application/native/
  background_uploader.dart
  document_outbox_adapter.dart
  native_document_session.dart
  native_notes_workspace.dart

nx_docs/lib/application/sync/document_synchronizer.dart
nx_docs/lib/data/local/drift/drift_local_notes_store.dart
nx_docs/lib/composition/notes_composition.dart
nx_docs/lib/features/shell/offline_sync_lifecycle.dart

nx_offline/lib/src/outbox/
nx_offline/lib/src/reconciliation/
nx_offline/lib/src/session/
nx_offline/lib/src/flutter/offline_lifecycle.dart
```

## Validation contract

Automated tests cover:

- cached mobile and desktop restart;
- cached session restoration while offline;
- web isolation from offline providers;
- original preference and database partition compatibility;
- atomic draft plus outbox persistence;
- claims, leases, retries, blocked work, and restart persistence;
- applied and stale document uploads;
- full Document and Book synchronization;
- per-document hash refresh;
- every full/keyed overlap direction;
- startup, resume, and connectivity triggers exactly once;
- an independent Expense-shaped reuse example in `nx_offline`.

The final acceptance gate is a clean analyzer and complete passing test suites
for both `nx_offline` and `nx_docs`.
