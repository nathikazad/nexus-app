# nx_cards

KGQL-backed one-direction flashcards with FSRS scheduling.

## Layers

- `domain/`: cards, decks, repository contracts, and the scheduler contract.
- `application/`: use-case services and ports such as the injected clock.
- `composition/`: Riverpod wiring. Presentation code depends on these providers,
  not on GraphQL.
- `data/remote/kgql/`: KGQL schemas, mapping, and the online repository.
- `features/`: auth, dashboard, editors, deck browsing, and study UI.

This mirrors the separation used by `nx_notes` and `nx_expense`. The current
composition binds `CardsRepository` to `KgqlCardsRepository`.

## Offline extension path

Offline support should be added without changing feature widgets or FSRS code:

1. Add `data/local/drift/` with deck/card tables. Store KGQL `updated_at` and a
   local dirty/tombstone state.
2. Add an application-level outbox and synchronizer, following `nx_notes`.
3. Implement a local-first `CardsRepository` that reads from Drift and writes
   local changes plus outbox entries.
4. Add a KGQL sync transport under `data/remote/kgql/`.
5. Change only `composition/cards_composition.dart` to bind the local-first
   repository on native platforms.

Each card keeps `due_at` and `suspended` as queryable KGQL attributes. Its
current FSRS snapshot is stored in versioned `schedule` JSON, while immutable
review events are stored in versioned `review_history` JSON. A review updates
all three pieces in one model mutation that can later be queued for upload.

Review IDs are generated on the client, allowing an offline synchronizer to
merge histories by ID and deduplicate the same review across devices.

## KGQL setup

After login, the app detects missing model types or required attributes and
presents an explicit setup action. Existing schemas are extended only when the
user invokes that action; ordinary startup does not mutate them.
