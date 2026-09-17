# NX Expense offline and sync redesign

Status: implementation in progress. Server contracts and native/web data-layer
foundations are implemented and tested locally. Existing screens still use the
old providers; the new composition root is deliberately not mounted yet. Nothing
from this phase has been deployed and no production events have been migrated.

## Implementation checkpoint

Implemented:

- Registered server Expense adapter, paged live reads, full model projections,
  reference/schema catalog, monthly collections and independent timeline items.
- Explicit per-domain event membership with stable sync IDs; a repeat-safe
  migration command for the user-approved assignment of legacy items to Home.
- Atomic model commands with durable operation-ID acknowledgements, revision
  preconditions, conflict responses and timeline linking in the same transaction.
- Receipt bytes finalized before an atomic event/domain/acknowledgement commit.
  Retries reuse the event; changed content cannot reuse the same operation ID.
- Native FileLibrary + shared Drift outbox, append-only operations, frozen retry
  requests, ordered edits, pending-write protection, receipt files and upload
  handler. New IDs and pending receipt references resolve before transmission.
- Shared sync session/supervisor composition, account/domain partitioning and
  ordered shutdown. Browser repository uses only live reads and memory caching.

Local checks: 40 server tests (shared database, Expense contracts and schema
reload), 143 Flutter tests, 9 explicitly skipped live GraphQL tests, clean analyzer.
The broader server runner stops at an existing Books test that opens a separate
connection without a selected domain (`test_epub_transcript_is_separate_preserved_and_hash_tracked`).
It therefore has not completed the later GraphQL acceptance stages.

Still required before rollout:

- Replace screen repositories/providers and direct widget transports across
  Expenses, Orders, Bank, Images, Tags, Stats and Budget; mount AppDataHost.
- Implement local query/aggregate projections, precise financial/category
  behavior, bounded foreground date filtering and visible coverage indicators.
- Add typed optimistic reducers and conflict/retry/discard UI, including
  relationship creation, schema/tag editing and pending-image presentation.
- Add attachment download/cache hydration; verify pending receipt linking and
  all session switches with in-flight work through screen-level tests.
- Verify concurrent command delivery and generic-write races. The current
  model-row lock needs acceptance coverage for concurrent relation/attribute
  writes through other API paths.
- Perform web/native builds, physical airplane-mode and cross-device checks;
  then deploy and run the explicit Home migration using verified IDs.

Current server projection rebuilds the complete Expense scope when dirty,
similar to the existing Hypnosis adapter. Hashes still prevent unchanged payload
downloads. Timeline invalidations currently conservatively fan out to registered
scopes; incremental heterogeneous routing/performance remains follow-up work.

## Existing behavior and reusable foundations

ExpenseFileCache is network-first fallback storage for previously requested
queries and models. Writes still call KGQL directly and invalidate cached data.
Bank events, image uploads, links and budget writes have separate access paths.
This is not a durable offline editing system; replace its repository wiring.

Books uses AppDataPolicy to select remote web repositories or native persistent
repositories. It uses AppReads for foreground reads and an AppDataSession for
freshness. Cards adds atomic local writes and a durable outbox. Its current
offline implementation does not support creating cards, so it is not a complete
template for Expense creation. Shared infrastructure is reusable; app-specific
mutation contracts still need to be implemented.

The server registry currently contains Cards, Docs, Books and Hypnosis. The
nx_expense directory currently contains its reconciliation skill only.

## Ownership and platform contract

- Server: register public app ID `expense`, with definitions, projections, read
  queries and mutation policy under `servers/nexus/apps/nx_expense/`. Reuse the
  shared runtime, authenticated domain access and state publication machinery.
- Shared mobile: nx_data owns platform policy and ephemeral view caching;
  nx_sync owns freshness triggers and revision/hash comparison; nx_offline owns
  durable pending operations, retry coordination and attachment queues.
- Expense client: owns typed repositories, local query tables, DTO mapping,
  command definitions, dependency ordering and conflict presentation. Widgets
  must not call GraphQL or upload endpoints directly.
- Native: render local data immediately, commit edits locally with their outbox
  entries, then synchronize. Downloads must not block the first usable screen.
- Web: live paged reads and server commands, with session-memory caching only.
  Do not construct SQLite, file libraries, durable outboxes or attachment
  prefetchers. Failed writes remain visibly unsaved; do not imply durability.

## Data scope

Cover Expense, Order, product lines, Company, Person, tag systems and nodes,
relationship edges, budget Goal definitions, bank timeline events, receipt
timeline events and their links. Include unlinked receipts and bank events as
independent items. Preserve timeline identity as event ID plus timestamp.
Preserve Amazon order/product URLs and image references. Historical provider
identifiers remain data details.

Use namespaced item identities and bounded collections: month-based expenses,
orders and bank events, an image catalog, and reference catalogs. Define exact
membership/date/timezone rules before implementing hashes. A date or relation
change must invalidate both former and new memberships. Discover and test
invalidation coverage for timeline events, links, tags, goals and permission
changes; model-family registration alone is insufficient evidence of coverage.

Native eventually synchronizes the authorized metadata library, prioritizing
the visible month and referenced detail records. Track collection completeness
explicitly. Never label a partial local aggregate as a complete total. Compute
Stats and Budget from the same local expense data, using the same decimal,
currency, date and category rules as server reads. Do not sum unlike currencies
without an explicit conversion policy.

## Read and refresh flow

Foreground reads use the shared live-read contract and do not wait for the sync
worker. Native merges successful reads into local storage; web retains only
session views. Background native synchronization uploads pending changes, checks
the authoritative manifest, fetches changed collections/items, and publishes a
consistent local snapshot while preserving newer local edits.

Use startup, resume, reconnect, subscription hints and periodic foreground
checks. Hints trigger authoritative checks; they are not a durable cursor.
Reject incomplete batches and stale revisions, retry refresh_required, and
advance a checkpoint only after successful application. Apply deletions only
from complete authoritative membership/removal information, never a filtered
page. Web uses changed-root detection to refresh observed views without fetching
an offline library.

## Durable write contract

Native writes an optimistic local change and a unique operation ID in one SQLite
transaction. New records use stable client IDs with a durable mapping to server
IDs; dependent commands retain client references until creation is acknowledged.
Create expense/order/person, edit fields, change tags, link/unlink records,
delete records and update budgets all go through this command boundary.

The server must authenticate the domain and atomically enforce operation-ID
deduplication, revision preconditions, mutations and stored acknowledgement.
A retry after a lost response returns the original result, including created
IDs. Existing generic KGQL calls are not assumed to provide this guarantee.
Multi-record commands such as creating an expense with its links must either
commit together or return an explicit non-success result.

Pulls never overwrite unacknowledged local edits. Conflicting changes retain
both versions for resolution; do not silently discard financial edits using
last-write-wins. An acknowledgement clears only the operation it covers, not
edits made while that operation was in flight. Permanent validation failures
remain visible and editable; transient failures retry with backoff.

## Receipts and other media

Save a captured receipt to durable native storage before reporting success,
with a local image identity and queued upload. It can remain unlinked indefinitely.
Upload bytes, obtain the canonical image event identity, then execute any queued
link operations. Add retry-safe upload/finalization semantics so a lost response
does not create duplicate timeline events. Preserve capture time separately
from server receipt time. A failed attachment must not block unrelated edits.

Queue thumbnails and full-size downloads separately from metadata. Show which
files are available offline. Web uploads directly and reports success only after
server acknowledgement. A receipt linked to an Order and Expense is still one
image event with multiple links.

## Session isolation and migration

Scope persistence and every in-flight operation to logical server, user, domain
and app using the shared session/storage identity. Wait for domain readiness;
dispose transports, subscriptions and repositories on session changes. Never
reassign pending work to another domain or fall back to an inferred domain.

Replace the old cache with a separately versioned store and rebuild confirmed
server data. Do not adopt old unscoped cache entries or erase pending data by
guess. Preserve business records and historical backlinks. Retire the old cache
only after the new path passes recovery tests.

## Implementation sequence and acceptance gates

1. Server Expense definition, typed payloads, live reads and sync projections.
   Verify RLS/domain boundaries, complete dependency invalidation, paging,
   deterministic hashes, obsolete revisions and deleted/moved items.
2. Server idempotent command and receipt-finalization contracts. Exercise
   concurrent edits, duplicate operation IDs, lost acknowledgements and atomic
   multi-record changes against real PostgreSQL.
3. Native local schema/repositories, atomic outbox and attachment queue; web
   remote implementations of the same interfaces. Test offline creation,
   dependent links, restart recovery and switching domains with pending work.
4. Rewire every screen: Expenses, detail/edit, Orders/products, Images, Bank,
   Tags, Stats and Budget. Remove direct widget transports. Show pending,
   failed/conflicting writes and incomplete download coverage where relevant.
5. End-to-end acceptance: create an expense and unlinked receipt in airplane
   mode, kill/reopen, reconnect, verify exactly one canonical record, then
   confirm the web reflects it. Test web edits flowing to the phone, concurrent
   edits, receipt retries, deletions, permissions, offline totals and zero web
   library persistence. Run native and web builds plus physical-device checks.

Deployment follows tested server/client compatibility. Any new native dependency
requires a new Shorebird base; Dart-only updates can use a compatible patch.
