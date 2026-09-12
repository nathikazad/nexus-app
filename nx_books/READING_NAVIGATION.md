# Reading navigation and companion ownership

- All full-screen reading surfaces use GoRouter, including EPUB source links.
  Dialogs and sheets may still use Navigator locally.
- `ReadingRoute` declares a reading identity and whether the route owns an EPUB
  passage. Plain routes (library, details, login) do not expose the companion.
- `ReadingCompanionHost` observes the router delegate's active configuration.
  Do not use `routeInformationProvider.value.uri` as the visible page: pushed
  routes may retain the underlying URL for platform reporting.
- The host and navigator remain mounted. `ReadingCompanion` receives identity,
  visibility, account scope, and an optional passage listenable explicitly.
- `readerPassageProvider(pageKey)` is scoped to a single route instance. The
  retained reader switches its passage binding on each open; old bindings are
  automatically disposed when no longer observed.
  Popping restores the underlying route's context without a global reset.
- `RetainedEpubHost` owns exactly one mounted renderer behind the navigator.
  A reader route controls visibility; popping hides the renderer with Offstage
  and disables tickers. Reopening preserves its controller, parsed HTML and
  pagination; source links use `jumpToLocation` rather than another load.
- `ActiveEpubCache` shares that same parsed EPUB with source resolution. Its key
  includes the book ID and file hash. Switching books, leaving the book flow,
  or changing accounts releases the slot. Memory pressure releases a hidden
  reader too. There is no multi-book in-memory cache.
- `EpubRouteRequest` contains already-prepared local reader inputs. File/source
  preparation failures leave the summary route untouched. Missing route extras
  show a recoverable message instead of constructing a reader with guessed data.
- The standalone EPUB renderer remains unaware of KGQL, auth, or companion
  providers. `EpubRoutePage` supplies its callbacks and handles persistence.
- Conversation storage remains keyed by document identity (Book, Document, or
  EpubBook). Changing routes flushes the old conversation and releases its live
  controller; returning selects the original identity and loads its history.

`test/reading_navigation_test.dart` covers summary → chapter → EPUB → back,
repeated opens, isolated nested readers, failed EPUB loads, non-reading routes,
and stable navigator/companion state. Keep this test when changing navigation.
`test/retained_epub_test.dart` checks actual renderer state identity across
hide/reopen and source jumps, position preservation, book replacement, and
memory-pressure eviction.
