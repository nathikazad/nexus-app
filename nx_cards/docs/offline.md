# Nx Cards offline architecture

## The story

Nx Cards has one domain API, `CardsWorkspace`, and two implementations:

- `WebCardsWorkspace` talks to KGQL directly. It has no SQLite database,
  outbox, background manifest sync, or persistent audio cache.
- `NativeCardsWorkspace` treats SQLite as the UI's data source. It uses the
  network only to reconcile that local projection with the server.

Riverpod chooses the implementation once from platform policy. Widgets do not
contain web/native branches and do not know how synchronization works.

## What synchronizes

A deck is the pull aggregate: deck metadata plus every card in the deck,
including the card's schedule and review-history JSON. The server computes one
canonical hash for that entire aggregate.

Cards use two Cards-specific GraphQL operations on the existing `/graphql`
endpoint:

- `mutateCardLibrary` applies a create, update, or delete. Updates and deletes
  are accepted only when `client_updated_at` is later than the server model's
  `updated_at`. The result includes the hashes of affected decks.
- `syncCardDecks` compares `{deck id, server hash}` manifest entries and returns
  canonical bundles only for missing or changed decks. It also reports decks
  deleted on the server.

The generic KGQL layer remains unaware of Flashcards, decks, hashes, schedules,
and review histories. The Cards GraphQL plugin is a thin SQL adapter; canonical
mutation, conflict, and hashing rules live in schema-owned SQL functions.

## Native launch

1. Restore the last logical account. The account key uses the user and the
   stable server id `nexus-primary`; LAN, WAN, and Tailscale are only routes.
2. Open that account's SQLite database.
3. Render the cached deck/card stream immediately, even without a server.
4. Trigger a full manifest reconciliation in the background.
5. Upload pending edits first, then compare the deck manifest, download only
   changed bundles, and prefetch their pronunciation audio.

No screen waits for the full library download. An empty first installation can
show an empty library while its first background reconciliation runs.

## Opening a deck

The screen reads the deck and cards from SQLite immediately. It then requests a
keyed reconciliation for only that deck. An equal hash transfers no bundle; a
different hash atomically replaces the local aggregate and redraws the stream.

Full and keyed requests pass through `ReconciliationCoordinator`, so opening a
deck during a full sync does not create competing refresh loops.

## Native edits and reviews

1. One SQLite transaction updates the typed card row and coalesces an outbox
   operation for that card.
2. The UI redraws immediately from SQLite.
3. The uploader claims the durable operation and calls `mutateCardLibrary`.
4. It performs a targeted deck reconciliation so unrelated server changes in
   the same JSON aggregate are not lost.
5. One transaction removes the outbox operation and applies the canonical
   server bundle.

A process kill cannot split the local edit from its outbox row. Both survive a
restart. Repeated delivery is safe, including a delete whose first response was
lost.

If the server reports `STALE`, its canonical deck wins. This intentionally
prevents an old laptop edit from overwriting later iPhone work.

## Ownership map

```text
features/                    UI and user intent
composition/                 Riverpod construction and platform policy
application/cards_workspace common interface used by UI
application/native/          local-first commands and outbox upload
application/sync/            full/keyed deck reconciliation
application/web/             direct KGQL behavior
data/local/drift/             typed cache + atomic OutboxStore adapter
data/remote/kgql/             Cards model mapping + sync transport
data/audio/                   remote bytes + native persistent cache
domain/                       framework-free Cards values and contracts
nx_offline                    generic outbox/retry/reconciliation/lifecycle
nx_db                         GraphQL client and typed Cards operations
server SQL                    canonical mutation, stale-write, hash, bundle
```

## Important constraints

- Native offline creates are not supported yet. Previously synchronized decks
  and cards can be read, edited, reviewed, suspended, and deleted offline.
- Reference lists such as languages, tags, and books remain network-backed.
- The app database is partitioned by logical account, so different users never
  share rows or pending operations.
- Audio failures never fail deck synchronization; cached audio remains usable.
