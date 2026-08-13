# Native offline synchronization

Cards are the only synchronization entity. Languages and books are projections
of card metadata: the `Language` tag and the `Book` relation respectively.

## Read path

1. Render the locally cached card snapshot immediately.
2. Upload pending local mutations.
3. Fetch the canonical card library from KGQL.
4. Replace synchronized local rows while retaining any row with a pending
   mutation.
5. Prefetch referenced audio opportunistically.

## Write path

Review, learning-status, suspension, content, and delete changes are written to
SQLite together with a durable outbox operation. The uploader calls
`mutateCardLibrary`, preserving card-level `updated_at` conflict detection, then
downloads a canonical card snapshot. A stale mutation restores the server card.

Native offline creates are not supported yet. Audio download failures never
fail card synchronization.

## Ownership boundaries

- `application/` coordinates snapshots and the outbox.
- `data/local/` owns Drift persistence.
- `data/remote/` owns KGQL mapping and transport.
- `domain/` contains deck-free card, scheduling, and grouping rules.
