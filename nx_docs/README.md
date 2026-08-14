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
