# Browser

The browser lets a person find cards through their language or source book.

`browser.dart` is its public vocabulary. `browser_page.dart` branches into
`language/` or `book_page.dart`, then through reusable `card_list/` views and
`card_details_page.dart`. `data/kgql/` fetches and translates server data;
`data/models/` contains the application-ready concepts consumed everywhere
else.

## Language-card connections

`word_phrases` is the historical name of the shared
`LanguageFlashcard -> LanguageFlashcard` relationship. Its direction is
**container -> contained card**: a phrase contains vocabulary, and a Chinese
word contains its character cards. Read outgoing (`child`) links as **Contains**
and incoming (`parent`) links as **Examples**. Never create a second edge for
reverse navigation. Keep `verb_phrase_conjugation` compatibility for its existing
person/tense-qualified links.

Examples carry the linked card ID, including in the offline JSON cache, so
navigation does not depend on matching display text. `linkedWordIds` remains the
legacy cache field name for outgoing Contains IDs. Character breakdown is now
read from saved links, not guessed when opening a card.

For new links, save from the larger expression to the contained card and specify
`relation_name: word_phrases`. The shared-ancestor definition includes Word,
Verb, Phrase, and Script without changing their model hierarchy.

### Incremental native synchronization

Cards and Books share `nx_offline.reconcileHashManifest`. Cards requests
`syncCards(manifestOnly: true)`, verifies account-scoped local hash/body markers,
and downloads only missing or changed IDs. The local SQLite v12 marker table is
populated on the first upgraded sync. Pending edits invalidate markers, and local
edit generations prevent in-flight pulls from overwriting new work. Deletions
are reconciled only after the complete manifest succeeds. Audio prefetch is a
single deduplicated background job with concurrency four.

The server computes set-based dependency hashes and uses the existing canonical
card payload builder only for requested bodies. Linked phrase text/audio changes
invalidate the words that display those examples. Keep hash dependencies aligned
with payload construction; bump its version when payload interpretation changes.
