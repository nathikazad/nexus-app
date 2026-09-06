# Offline storage: follow one document

## 1. A file holds the content; SQLite tells us which file is current

Native apps store large document payloads in the application's persistent,
private support directory, not in preferences or a permanently resident Dart
map. The logical layout is:

```text
offline/<account-hash>/
  documents/remote-123/<content-sha256>.json
  cards/456/<content-sha256>.json
  Book/789/<content-sha256>.json
```

SQLite stores small references: relative path, checksum, byte length, and the
app's list/sync metadata. Account names and unsafe IDs are hashed; titles live
inside the JSON, not in mutable filenames. An account includes the application,
logical server and user. Different apps do not share each other's private files.
Changing a network route to the same logical server does not change identity.

On Android this is internal flash storage. RAM is used temporarily for an open
document, a sync page, SQLite's bounded page cache, and the list projections the
UI currently retains. Increasing stored content does not require loading all
that content into RAM. Opening one exceptionally large document can still be
expensive; file storage alone cannot eliminate editor/rendering costs.

## 2. Save bytes before publishing their reference

Read the implementation in this order:

1. [content_files.dart](../lib/src/storage/content_files.dart) describes the small
   file reference and the common read/write/availability contract.
2. [content_files_native.dart](../lib/src/storage/content_files_native.dart)
   encodes and hashes the content, flushes a staging file, then atomically
   renames it to its immutable destination. Large encoding, hashing and decoding
   operations use a worker isolate. Reads check size and checksum. Missing or
   damaged files raise errors; they are not silently returned as empty content.
3. [library.dart](../lib/src/storage/library.dart) publishes the reference and
   projection in SQLite. Local content and pending state change in one SQL
   statement. Saves are serialized in invocation order. Catalog replacement is
   a transaction over immutable file references, including empty catalogs.
4. The app's existing sync code sends a queued file version and acknowledges
   only the matching operation. `FileLibrary` has a separate integer generation:
   editing A → B → A must not make an old receipt current merely because the
   checksum matches again.

A failed file write cannot publish a new database pointer. A failed database
transaction leaves the old pointer valid and may leave an unreferenced new
file. This favors retaining data over deleting it prematurely.

## 3. Each app owns its small projection, not its own file protocol

| App | SQLite retains | Files retain | Read behavior |
| --- | --- | --- | --- |
| Docs | Catalog summaries/membership, timestamps, server hashes, sync state, outbox references | Full documents, local snapshots and conflict payloads | Lists/search/manifest avoid body reads; open one document on demand |
| Books | Bookshelf headers, document references/revisions, catalog coverage | Each cached Book/Document payload and bookshelf record | Header lists read the index; document bodies migrate from preferences and load on demand |
| Expense | Query membership/coverage, record references, cached aggregate results | Model responses and schemas | Only previously downloaded, exact query ranges/projections can fall back offline; unknown coverage is an error, not an invented empty result |
| Cards | Short front/back previews, tags, schedules, up to ten recent reviews per cue, sync/outbox state | Full front/back, examples, complete review history and queued versions | Dashboard reads projections; details and selected study sessions hydrate full cards |

Docs and Cards keep their existing typed SQLite tables and transactional outbox
integration. Books and Expense use `FileLibrary`'s small generic index. Both paths
share the same file format and file-publication mechanism; domain mapping and
sync rules remain inside the app. This avoids replacing working domain sync
behavior with a second generic sync engine.

Docs downloads bodies in batches of twenty after lightweight header discovery.
It no longer rebuilds every catalog on a single save. Search filtering runs in
SQLite, old summary bodies are removed in schema version 6, and unused search
and document providers can be released. Large document encoding/decoding is
moved off the UI isolate where practical.

Cards keeps full-body objects out of its dashboard. A summary is explicitly
marked and cannot be saved as if it were a complete card. A successful review
upload no longer downloads the entire library. Rejected writes still use the
existing canonical-refresh behavior. Audio prefetch hydrates one card at a time.

## 4. Upgrade without discarding the old source first

Docs exports legacy inline documents in batches of 25, with conditional pointer
updates so a concurrent edit is not overwritten. Snapshot and conflict payloads
are also exported. New saves immediately use files; the first sync manifest
finishes migration without making catalog rendering wait for the network.

Cards adds `content_ref` in database version 10 and exports legacy rows in
batches of 25 before exposing the slim dashboard. Bodies are finalized before
the old row is reduced to its projection. Pending work stays in the existing
outbox.

Books removes a legacy preference key only after a file/index round trip verifies
the source content. Interrupted work resumes by remaining keys. An existing newer
canonical copy is preserved, with the legacy copy indexed separately. Background
hydration compares the shelf revision and checks file availability, rather than
assuming that an index row alone means the body is available forever.

SQLite may retain freed pages after migration. Its physical database file will
not necessarily shrink immediately; avoiding a startup `VACUUM` prevents a
large blocking rewrite. Normal application uninstall/storage clearing still
removes app-private data. This is persistence, not an independent backup.

## 5. What this change does not claim

- Books and Expense keep their existing network-backed mutation behavior and
  authentication gates. This change adds file-backed caches, not a new offline
  transaction editor or authentication design.
- Expense invalidates cached coverage/totals after online mutations. It does not
  claim complete offline coverage of unseen date ranges, Teller data or arbitrary
  related-model APIs. Cached responses are last-known server results.
- Existing app conflict resolution and server idempotency/cursor limitations
  remain. The file layer does not solve server protocol limitations.
- Catalog APIs offer bounded pages, but some existing screens still accumulate
  all lightweight headers. Cards' full-library network pull still uses its
  existing server snapshot API. These can scale with item count, even though
  they no longer keep every full body alive in the dashboard.
- There is no automatic old-version garbage collection yet. Immutable history
  and abandoned staging files are retained until a reference-aware retention
  policy is implemented. Disk usage can therefore grow across repeated edits;
  cleanup must account for current bodies, queued versions, snapshots and
  conflicts before removing anything.
- Web retains its existing remote/preference behavior; native filesystem
  storage is never opened on web.
- The Android build is checked, but no Android device was connected for memory,
  frame-time, cold-start or force-stop profiling. Debug-build success is not
  evidence that the lag is resolved.

## 6. Verification

The executable tests live alongside the code they exercise:

- Shared: [file_library_test.dart](../test/file_library_test.dart): real temporary
  files and file-backed SQLite; restart, immutable queued versions, A → B → A,
  concurrent saves, corruption, missing files, traversal/symlink rejection,
  transaction rollback, atomic catalog publication, and a 1,000-item metadata
  paging check.
- Docs: [file_storage_test.dart](../../../nx_docs/test/sync/native/file_storage_test.dart)
  runs the existing store contract against files and SQLite, plus migration,
  metadata-only reads and old-upload/new-edit protection. Snapshot contracts also
  exercise real files.
- Cards: [file_storage_test.dart](../../../nx_cards/test/sync/file_storage_test.dart)
  checks migration, bounded previews/history, no dashboard body reads, full-card
  hydration, pending-version isolation and rejection of summary-only saves.
- Books: [file_storage_test.dart](../../../nx_books/test/file_storage_test.dart)
  checks verified preference migration and metadata-only cache checks.
- Expense: [file_storage_test.dart](../../../nx_expense/test/file_storage_test.dart)
  checks exact query coverage, downloaded-empty versus unknown, offline reads,
  metadata-only totals and invalidation.

The broader [acceptance specification](file_storage_test_spec.md) remains the
release checklist. Process-kill/power-loss tests, 10k/100k scale runs and physical
Android performance gates are not implied by these unit/contract test results.
