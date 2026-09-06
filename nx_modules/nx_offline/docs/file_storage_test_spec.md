# File storage acceptance tests

Status: release acceptance checklist for the file-content / SQLite-index migration.
A subset is now executable; see [implementation and verification](file_storage.md).
Scenario identifiers below are requirements, not a claim that every case is
implemented or passing. Device profiling, process-kill and larger-scale gates
still require separate verification.

Applies to `nx_docs`, `nx_books`, `nx_cards`, and `nx_expense` (the repository's
singular package name). Native applications use the same storage mechanics in
separate app containers. This specification does not imply shared physical
storage across apps or introduce browser offline support.

## The story the tests follow

Browse the index → open content → save locally → synchronize → recover and
clean up. A reader should be able to follow that sequence through the tests.

The durable content is an immutable, versioned JSON file or binary attachment.
SQLite holds the current file reference, a queryable summary, local generation,
server revision, availability, and durable upload state. A file is finalized
before the SQLite transaction publishes its reference. Successful local save
means that transaction committed; network acknowledgment is a separate event.

Keep these concepts distinct in fixtures and assertions:

- A local generation identifies one committed edit.
- A local checksum verifies stored bytes; it is not automatically comparable
  to a server hash computed over a different representation.
- A server revision/hash describes the last observed or acknowledged remote
  version, not proof that an offline client knows the current server state.
- Content availability and synchronization state are independent. Metadata can
  be current while the corresponding body is not downloaded.

## Test layout and harness

Planned shared suites live under `test/storage/`. Shared contract registration
and fixtures live under `test/support/storage_contract.dart` and
`test/support/storage_fixtures.dart`. Each application's
`test/storage/<app>_storage_test.dart` runs the same behavioral contract against
its real adapter and adds domain-specific assertions.

Expose a deliberate test-support entry point if cross-package reuse needs it;
applications should not reach into another package's private test directory.
Keep the contract assertion implementation in one place. Do not copy four
versions of file handling, recovery, or upload-race tests.

The harness supplies:

- Real files in a fresh temporary directory and real file-backed SQLite.
  In-memory stores alone cannot pass persistence acceptance.
- Deterministic IDs, a fake clock, and explicit asynchronous barriers. Race
  tests wait at named boundaries rather than guessing with sleeps.
- A scripted server that records requests and supports delayed responses,
  revision changes, lost acknowledgments, and paginated partial failures.
- File I/O counters (opens, bytes, writes), database statement/row diagnostics,
  downloaded bytes, worker concurrency, retained cache bytes, and subscription
  counts. Reset counters after fixture setup.
- Injected write, flush, rename, and transaction failures. Inject faults at the
  actual storage boundary, not only in a fake repository.
- Teardown that closes connections and removes only the test's own temporary
  directory. Tests never modify installed app databases or user preferences.

Start with 1 KB, 100 KB, 1 MB, and 10 MB UTF-8 content, including Chinese,
emoji, multiline text, nested editor nodes, and empty optional fields. Use
deterministic pseudo-random binary attachments, shared references, and a
corrupt/truncated file. Include two accounts, two logical servers, identical
remote IDs in different collections, and local items without remote IDs.

## Browse and open

### `library_index_test.dart`

- **IDX-01:** Fetch a page with title, excerpt, tags, and sync status. Assert
  exact expected results, the configured row limit, and zero body-file reads.
- **IDX-02:** Sort and page items with identical timestamps using a stable ID
  tie-breaker. In an unchanged dataset, every item appears once with no gaps.
  Define refresh behavior when rows change between pages; do not claim a
  snapshot across independent queries unless implemented.
- **IDX-03:** Filter tags, collection, pinned state, and availability through
  the index. A missing body does not hide a valid metadata-only item.
- **IDX-04:** The same IDs under another account/server/collection never appear
  in a query, lookup, upload, or cleanup scoped to this identity.
- **IDX-05:** Change LAN/WAN/Tailscale routes for one logical server. The same
  local items and pending operations remain selected.

### `content_files_test.dart`

- **FILE-01:** Save, close, reopen, and decode each fixture. Assert semantic
  equality of the complete content, not only title or file existence.
- **FILE-02:** Verify finalized bytes against the recorded checksum and size.
  Truncated, malformed, or checksum-mismatched content produces an explicit
  unavailable/corrupt result, never a silently empty document.
- **FILE-03:** Reuse identical content within the defined storage scope. Assert
  the expected immutable file is reused and references remain independent.
- **FILE-04:** Rename an item without changing its stable identity. References
  remain valid and no title-derived path is required.
- **FILE-05:** Reject traversal/absolute paths and prevent file operations from
  escaping the account root, including symlink escapes where supported.
- **FILE-06:** Unsupported envelope versions produce an actionable error and
  preserve the bytes for recovery or migration.
- **FILE-07:** A missing clean body may be downloaded again. A missing body
  referenced by a pending local edit blocks upload visibly; it must not be
  replaced with remote content and reported as a successful local save.

### `content_cache_test.dart`

- **CACHE-01:** Fill the cache beyond its configured byte budget. Unpinned
  entries are evicted until within budget; the disk copies still reopen.
- **CACHE-02:** Concurrent opens of one generation share one file load. A new
  generation cannot return stale decoded content from the old cache entry.
- **CACHE-03:** Closing a view releases its content pin. After disposal, only
  deliberately retained entries and active documents remain reachable.
- **CACHE-04:** A document larger than the cache budget opens as active content
  but is not retained in the unpinned cache on close. Track active bytes
  separately so a budget claim does not conceal oversized pinned content.
- **CACHE-05:** Prefetch observes both concurrency and byte limits. Cancelling
  a study session or changing account stops obsolete prefetch work.

## Save locally

### `save_item_test.dart`

- **SAVE-01:** A successful save references a finalized valid file and commits
  the new generation, projection, and pending operation together. Reopen from
  a fresh store and assert all four agree.
- **SAVE-02:** Fail file write, flush, or rename. The previous committed content
  and pending operation remain valid; the caller receives failure.
- **SAVE-03:** Finalize a file, then fail the database transaction. No new
  summary or queue entry becomes visible. The previous generation remains
  current; the unused new file is eligible for later cleanup.
- **SAVE-04:** Edit item A in a large library. No unrelated body is read or
  written, and no whole-library catalog delete/reinsert or scan occurs.
- **SAVE-05:** Two saves to the same item overlap. Their generations and
  publication order remain consistent; an earlier asynchronous completion
  cannot replace the later accepted edit.
- **SAVE-06:** Repeated saves coalesce queued work without losing the newest
  committed generation. An in-flight generation remains protected separately.
- **SAVE-07:** Changes to tags or scheduling update only affected projections.
  Small metadata edits do not require opening unrelated content files.
- **SAVE-08:** Disk-full/write-denied errors leave the previous version usable
  and visible as such. The UI never displays a durable-save acknowledgment for
  an edit that failed to commit.

## Synchronize

### `upload_changes_test.dart`

- **UP-01:** Claim generation A, commit generation B, then acknowledge A.
  B stays current and pending; A's receipt cannot mark B synchronized.
- **UP-02:** An upload sends the exact immutable version it claimed, even if
  the current index reference changes while the request is running.
- **UP-03:** Retry preserves operation identity. A new edit receives appropriate
  generation identity without mutating a request already in flight.
- **UP-04:** Restart during a claim; after lease expiry another worker can
  continue. Simultaneous workers cannot own the same unexpired claim.
- **UP-05:** Authentication/validation/conflict failures remain blocked until
  the relevant condition is resolved; transient errors use scheduled retry.
- **UP-06:** Server accepts a create but its response is lost. Retry produces
  one remote item and binds the original local ID to it. This gate requires
  real server idempotency support; a scripted server alone cannot prove it.
- **UP-07:** Switch accounts while a response is outstanding. Its receipt can
  only affect the original account and generation.

### `reconcile_item_test.dart`

- **REC-01:** Equal acknowledged server versions cause no content download,
  body write, or content-generation notification.
- **REC-02:** Apply a changed remote body through the same file-before-index
  commit protocol. Failure preserves the previous consistent version.
- **REC-03:** Remote change overlaps a pending local edit. Retain both versions
  and expose the chosen conflict policy; never silently discard the local one.
- **REC-04:** Resolve a conflict, restart, and verify the selected content and
  resulting pending operation. Cleanup cannot remove unresolved versions.
- **REC-05:** Local checksum and server hash use their declared encodings.
  Different equivalent serializations do not cause endless upload/download
  cycles or false corruption results.
- **REC-06:** While offline, show pending local work and last checked time.
  Do not claim current remote equality without a successful remote check.

### `sync_batches_test.dart`

- **BATCH-01:** Build metadata comparisons from index columns with zero body
  reads. Process large comparisons with bounded rows and bytes per batch.
- **BATCH-02:** Initial download and changed-content hydration obey configured
  concurrency and byte limits; oversized single items have explicit handling.
- **BATCH-03:** Fail a middle page. Already committed pages remain usable;
  resume does not duplicate records or skip the failed page.
- **BATCH-04:** Advance a cursor/completion marker only in the transaction that
  commits the corresponding results. Restart before that transaction replays
  safely. Exercise only cursor semantics actually supplied by the backend.
- **BATCH-05:** Coalesce startup, resume, connectivity, and foreground demand
  through the existing supervisor; do not run duplicate full syncs.
- **BATCH-06:** The real endpoint passes bounded-response checks. Locally
  splitting an already downloaded giant JSON response does not meet this gate.

### `deletions_test.dart`

- **DEL-01:** Local deletion is durable and queued after restart; physical
  content needed for upload, conflict handling, or recovery stays protected.
- **DEL-02:** Remote deletion removes a clean item from live results. A pending
  local edit takes the explicit conflict path instead of disappearing.
- **DEL-03:** Absence from a partial page, failed response, filtered query, or
  incomplete date range is never interpreted as a deletion.
- **DEL-04:** Authoritative deletion and later recreation retain correct
  identity semantics. Retrying a delete does not delete a different item.

## Recover and clean up

### `restart_recovery_test.dart`

Run injected-failure tests at every boundary below. Also run a subprocess
subset that terminates without calling store close or Flutter dispose:

| Interruption boundary | Required state after reopening |
| --- | --- |
| During temporary-file write | Previous committed version opens; partial file is never current |
| After finalization, before DB transaction | Previous version remains current; new file is unreferenced |
| During DB transaction | Previous or complete new transaction, never a mixed projection/queue/reference |
| After commit, before UI notification | New generation opens and upload is still queued |
| After remote acceptance, before receipt commit | Local work remains retryable with its original identity |
| During migration or maintenance | Migration resumes; every protected reference remains valid |

Signal readiness through a child/parent handshake, then kill the child at the
specified boundary. Record observed committed state; do not use arbitrary
sleep durations to infer it. Process-kill coverage is not a claim of power-loss
durability: platform flush/directory durability behavior requires a separate
audit and, where available, platform-specific fault testing.

### `attachments_test.dart`

- **ASSET-01:** Imported/downloaded binary bytes, length, and checksum match.
  Interrupted downloads remain incomplete and cannot be returned as valid.
- **ASSET-02:** Two items reference one attachment. Removing one reference does
  not delete the other item's attachment.
- **ASSET-03:** A required attachment finishes uploading before a dependent
  mutation publishes its remote reference. Retry preserves dependency state.
- **ASSET-04:** Explicit offline downloads survive ordinary cache eviction;
  opportunistic media follows the configured retention policy.

### `maintenance_test.dart`

- **GC-01:** Remove only unreferenced eligible generations and abandoned
  staging files. Protect current, queued, in-flight, conflict, snapshot, and
  migration references.
- **GC-02:** Pause a save after finalization but before publication and run
  cleanup. The pending publication remains protected. Repeat with attachment
  import and conflict creation to test the same ownership boundary.
- **GC-03:** Cleanup is bounded and resumable, and does not scan every file at
  every application startup or save.
- **GC-04:** Logout closes work and observers while applying the documented
  retention policy. Removing one account's data cannot touch another account.

### `migration_test.dart`

- **MIG-01:** Use fixtures from actual old schema shapes: Docs body rows and
  outbox, Books preferences JSON, Cards rows/history/outbox. Expense starts
  fresh because the current app has no equivalent durable offline library.
- **MIG-02:** Compare semantic content, IDs, projections, and pending-operation
  meaning before and after migration; byte equality is not required across
  different encodings.
- **MIG-03:** Interrupt every migration checkpoint, reopen, and resume. No
  duplicate items, silently synchronized drafts, or missing generations.
- **MIG-04:** Verify exported files before changing active references. Retain
  old storage until migration validation is complete; reject corrupt source
  entries visibly instead of skipping them and declaring success.
- **MIG-05:** Coordinate or block concurrent edits during cutover. The last
  accepted pre-cutover edit must appear in the new store.
- **MIG-06:** Re-running completed migration is harmless. Unsupported downgrade
  behavior is explicit; old binaries must not silently write a second live
  copy after cutover.

## Application contract extensions

| App test file | Additional assertions |
| --- | --- |
| `nx_docs/test/storage/docs_storage_test.dart` | Editor formatting, Unicode text, links, highlights, drawings, and asset references survive reopen. Saving one document does not rebuild catalogs. Scroll/view state does not enqueue shared content changes. |
| `nx_books/test/storage/books_storage_test.dart` | Preferences migration preserves notes, summaries, progress, tags, and rank. Bookshelf reads zero bodies. Chapter identities remain independent. Downloads resume without repeatedly parsing every cached body. |
| `nx_cards/test/storage/cards_storage_test.dart` | Due counts and queue selection read only indexed scheduling fields. Current card plus bounded prefetch loads complete content. Reviews preserve schedule and history across restart; rapid reviews during upload lose no accepted events. |
| `nx_expense/test/storage/expense_storage_test.dart` | Date ranges, exact amount representation, currencies, categories, relation IDs, and exclusion flags survive reopen. Totals require no detail files and do not combine currencies incorrectly. Incomplete date coverage is visible. Expense/order/transfer links and local creates survive ID assignment. |

Domain policies stay in app tests; all file publication and generation-race
assertions belong in the shared contract. Existing Expense reuse tests prove
the shared supervisor can host Expense-shaped work, not that the Expense app
already supports offline persistence.

## Efficiency gates

`test/storage/storage_scaling_test.dart` uses index datasets of 1,000, 10,000,
and 100,000 items. Use a representative mixture of body sizes; avoid creating
100,000 large bodies just to test an index-only query. Run the largest fixtures
in a dedicated scheduled/manual suite, with 1,000 items in ordinary CI.

Count work after seeding and exclude intentional fixture setup and teardown.

| Operation | Hard assertion |
| --- | --- |
| Browse a page or query totals/due counts | Zero body reads; result count within limit where applicable |
| Open one uncached item | Only its body is loaded, apart from explicitly budgeted prefetch |
| Save one item | No unrelated body reads/writes or full-library scan/rewrite; index changes scale with this item's fields/tags |
| Compare sync versions | Zero body reads; metadata batches respect row/byte limits |
| Sync unchanged library | Zero body downloads and writes; no spurious content-generation events |
| Dispose 100 distinct searches | Active observers return to the pre-test baseline |
| Open/close 100 distinct items | No growth in retained sessions; unpinned cache stays within budget |
| Background hydration | Observed worker count and bytes in flight stay within configured bounds |

An indexed query still has lookup cost that can grow with the dataset. Assert
the absence of full scans on hot paths using query plans and row diagnostics,
not a blanket claim that every operation has constant CPU time. Deterministic
counter assertions are ordinary CI gates; elapsed time is a separate device
measurement.

## Android performance gate

Planned entry point in each app:
`integration_test/android_offline_performance_test.dart`.
Begin with Docs on the affected 8 GB Android device.

Record device model, Android version, refresh rate, build mode/commit, dataset
counts and bytes, initial cache state, thermal conditions, and network profile.
Use profile builds for diagnosis and confirm user-facing behavior in release.
Do not compare debug-build times with release targets.

Scenario: cold offline launch → warm library page → scroll → open a document →
type and pause to save → search 100 distinct queries → open/close documents →
repeat while syncing → force-stop → reopen offline and verify accepted saves.

Initial targets, subject to explicit baseline review rather than silent loosening:

- At least 95% of measured interaction frames stay within the display's frame
  budget (16.7 ms at 60 Hz); report UI and raster timings and long stalls.
- Warm first library page: p95 at most 200 ms from navigation to rendered rows.
- Small-document local save: p95 at most 100 ms from save invocation to durable
  commit for the 100 KB fixture. Report typing debounce separately.
- Background sync keeps the same frame gate and adds no more than 20% to p95
  warm-page/save latency versus the paired no-sync run.
- Repeat three 100-item open/search/close cycles. After disposal and controlled
  settling/GC in the diagnostic run, live sessions/watchers return to baseline
  and decoded caches meet their budgets. Report Dart heap and process memory
  separately; investigate continued retained-object growth with heap snapshots.
- Every save acknowledged before force-stop reopens with the expected content.
  Edits still inside the debounce window are measured separately and must not
  be mislabeled as acknowledged saves.

Use at least 30 timed warm-page/save samples per condition and report p50,
p95, maximum, sample counts, and raw frame data. Measure large-document open
and edit behavior separately; small-document latency targets are not promises
for arbitrary 10 MB editor trees. Cold launch is recorded as a baseline metric
until a device-specific target is agreed.

## Delivery order and completion evidence

1. Capture Android baseline and preserve existing shared/app test results.
2. Implement real-file harness and file/index/save/recovery contract tests
   alongside the shared storage implementation.
3. Add upload generation, reconciliation, deletion, and cleanup race coverage.
4. Run the contract through Docs and verify migration and Android improvement.
5. Apply the same contract to Books, Cards, and Expense with domain extensions.
6. Run real-server idempotency, revision, deletion, and bounded-response tests
   against an isolated test database; complete the large scaling suite.
7. Record final device results and residual limitations before rollout.

For each gate, the implementation record must identify test names, command,
commit, result, and any required device/server artifact. A skipped test, a
mock-only server success, or an unavailable Android device does not count as a
passed gate. Do not add permanently skipped placeholder tests merely to make
this file tree appear implemented.

Completion requires both correctness and the measured Android interaction
gate. Passing file round-trip tests alone does not complete the migration.
