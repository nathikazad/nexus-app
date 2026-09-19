# Nx Docs

Nx Docs is a local-first document workspace for writing, organizing,
linking, publishing, and discussing long-form documents. Its source tree is a
table of contents for that product:

```text
main -> app -> account -> workspace -> library -> documents -> publishing
                                      -> books   -> companion
                                                   -> sync
                                      -> settings
```

## Reading the application

Start at `lib/main.dart`, then read `app/docs_app.dart` and `app/routes.dart`.
The remaining top-level folders name product capabilities:

```text
lib/
  main.dart       process entrypoint
  app/            Flutter root, routes, theme, and version
  account/        login and cached-session restoration
  workspace/      responsive desktop/mobile document workspace
  library/        catalogs, search, and document discovery
  documents/      document vocabulary, editing, assets, and KGQL adapters
  books/          book context and chapter selection
  tags/           tag systems and derived indexes
  companion/      AI chat, transcripts, audio, and live conversation
  publishing/     publication state and mirror triggers
  sync/           native persistence, outbox, reconciliation, and web access
  settings/       user-controlled application preferences
```

Each capability exposes a same-named entry point, such as
`documents/documents.dart`. Technical folders are scoped beneath their owner:
KGQL document adapters live in `documents/data/kgql`, while Drift and the
outbox live in `sync/native`.

## Boundaries

- `app/` contains only application startup concerns.
- Application models do not import Flutter, Riverpod, KGQL, Drift, or HTTP.
- UI consumes document and catalog vocabulary rather than backend rows.
- Each capability owns its providers and production adapters.
- Native persistence belongs to `sync/native`; remote synchronization belongs
  to `sync/remote`.
- Web selects direct remote implementations in `sync/web`.
- Generic top-level `core`, `data`, `domain`, `features`, and `utils` folders
  are not allowed.
- Tests mirror the production capability tree.

Production Dart files normally contain 50–1000 lines. Small entrypoints,
facades, contracts, and platform stubs are legitimate exceptions; generated
files are exempt. Files over 1000 lines must be divided by a recognizable
workflow step or independently testable responsibility.

These rules are enforced by `test/architecture/narrative_boundaries_test.dart`.

## Local-first runtime

Native applications restore the cached account, open its Drift library, render
cached documents, and synchronize through the shared `nx_offline` supervisor.
Edits commit to the local document and outbox in one transaction. Web builds do
not open Drift and use the remote document workspace directly.

Provider ownership follows the same story:

```text
account/account_providers.dart       cached identity
sync/sync_providers.dart             database, transport, uploader, sync
workspace/workspace_providers.dart   native/web workspace selection
documents/document_providers.dart    document sessions, history, and links
library/library_providers.dart       catalog and search streams
publishing/publishing_providers.dart publishing services and triggers
```

## Web deployment

The server retains the legacy `nx_notes` static directory for deployment
compatibility:

```sh
flutter build web --release --base-href /docs/
rsync -az --delete build/web/ ../../servers/mcp/server/static/nx_notes/
```

## Native library synchronization

Docs and Books share `nx_offline.reconcileHashManifest`, download progress types,
and the `nx_db.syncDocuments` server API. A full Docs check first fetches a
manifest-only response, verifies matching local content references without
loading bodies, then downloads only missing/changed bodies in pages of 20.
Deletions are reconciled after the complete manifest pass. Unsent local edits
are never replaced by downloads or server deletions.

Library and foreground requests use separate shared `SyncSupervisor` instances.
Foreground document demand therefore need not wait for the entire library.
Each downloaded/deleted document carries the local hash observed before the
request; the local store checks it inside the write transaction, preventing a
late library response from overwriting a newer foreground result or upload.
Uploads keep their durable outbox and run independently of pulls. Settings shows
upload state separately from library progress and automatic retry errors. The
library supervisor uses Books' bounded exponential retry policy; providers close
both supervisors when the account scope is disposed. Sync phase/count timestamps
are logged with the `[NX Docs sync]` prefix without document bodies or credentials.

## Canvas persistence and performance

The native canvas runtime is owned by `nx_modules/nx_canvas`; see its README for
worker ownership, tile rendering, durable stroke recovery, and tablet checks.
Docs owns `documents/editor/nx_canvas_session.dart` for periodic document/outbox
saves while the native editor is open. Canvas diagnostics remain on the tablet;
Docs does not upload them to the server logs table. See the canvas module README
for the local capture command. Local canvas saves do not depend on network availability.

Canvas architecture: [shared module boundaries](../nx_modules/nx_canvas/ARCHITECTURE.md).
Docs uses the typed `CanvasClient` API; `MainActivity` contains no canvas protocol.
The drawing format and local journal remain compatible with existing documents.
