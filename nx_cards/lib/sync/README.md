# Sync

Sync makes the card library local-first on native platforms. `native/` owns the
Drift store and outbox, `remote/` owns upload and snapshot transport, and
`lifecycle.dart` decides when synchronization runs. It does not decide what a
review means or when a card is due.
