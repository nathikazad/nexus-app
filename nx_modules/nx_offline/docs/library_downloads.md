# Library downloads

Both Nx Docs and Nx Books use the same sequence:

1. `OfflineLifecycle` requests a sync after login/startup, app resume, or a
   connectivity recovery. The settings action can await that same sync.
2. `SyncSupervisor` serializes requests and coalesces overlapping full syncs.
3. `pullLibrary` deduplicates discovered and known keys, processes pages of 20,
   and awaits each page's persistence before starting another.
4. App adapters compare revisions and write bodies to files with a small index.
   A failed page propagates an error; the next run skips content already saved.

Nx Docs retains its server hash protocol, deletion reconciliation, and pending
edit protection. Its page adapter downloads changed bodies in a server batch.
Nx Books discovers Book and Document headers and checks each file's stored
revision. Its page adapter downloads individual bodies sequentially, keeping
only one newly decoded body at a time. Chapters stored as Documents are included
even when never opened. External image/audio assets and other model types are
outside this catalog. Nx Books retains cached entries removed from the catalog;
its read cache does not yet implement Nx Docs' deletion protocol.

Transport, document mapping, and merge rules stay in each app. The shared module
does not depend on either app's schema or GraphQL client.
