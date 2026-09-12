# EPUB reader trial — 2026-09-12

Update: NX Books now uses native page-by-page navigation. The original
scrolling-trial measurements below are historical; see the pagination follow-up
at the end for the changed layout behavior.

## Decision

Use the Flutter-rendered `epub_view` candidate for this first trial. The original
dependency conflict is resolved in small local EPUB forks, with no changes to
AppFlowy or its PDF version. Do not call this a proven memory winner: EPUB.js
was investigated but not benchmarked alongside it.

## Options investigated

| Option | Finding |
| --- | --- |
| epub_view 3.3.0 | Pure Flutter, desktop/mobile, paragraph-oriented CFI. Chosen and tested. Its epubx parser needed image/archive migration. |
| flutter_epub_viewer 2.0.0 / EPUB.js | WebView approach with broader browser layout support. Wrapper inspection found continuous rendering, whole-file base64 transfer and permissive navigation/permission handling. Prototype removed from app; not benchmarked. |
| flutter_readium | Not selected for the initial shared Mac/Android trial; native macOS support was not suitable in the inspected wrapper. |

Sources: https://pub.dev/packages/epub_view,
https://pub.dev/packages/flutter_epub_viewer,
https://pub.dev/packages/flutter_readium.
Fork provenance and exact deltas are in each `third_party/epub*/NEXUS.md`.

## Implemented boundaries

- KGQL/cache resolves the local file; the reader has no database/auth/sync logic.
- EPUBs open on their own Flutter route with a Back button; PDFs keep the
  existing file opener. Optional starting CFI is a reader concern.
- Local file picker is available at login and in settings for evaluation.
- Parser runs in a temporary background isolate; renderer creates visible
  paragraph widgets lazily. Book contents are still loaded eagerly.
- Typed image buffers reused; unnecessary cover decoding skipped; decoded
  image width capped at 1200; reader-owned image cache entries evicted on close.
- No embedded browser, loopback server, CDN, or remote image fetch needed.
- 64 MiB compressed / 128 MiB declared expanded / 20,000-entry limits. These
  are resource guards, not comprehensive hostile-file security guarantees.

## Results

Machine: MacBookPro18,4, 64 GiB RAM. Installed a signed-verified macOS release
at `/Applications/Nexus Books.app` (77.9 MB bundle). Android debug APK also built;
no Android device performance measurement or iPad test has been performed.

Test book: user-provided Seven Powers EPUB, 10,909,187 bytes, 85 images,
15 top-level chapters, 24 flattened contents entries.

- Parsing: 164 ms on first isolated test, 86 ms on a later run. These are
  Flutter test-runner measurements, not tablet timings.
- Installed release initialization indicator: 0.1 s (parse + initial layout
  callback; not a guarantee that every image has decoded by this time).
- Visually verified: cover, contents drawer, jump to Chapter One, larger text,
  scrolling, Figure 1.1, and Back returning to login.
- Automated actual-book test visits all 24 contents entries without rendering
  exceptions; that does not prove every layout or navigation target is exact.
- 84 NX Books tests passed, plus 22 upstream reader tests. Two optional
  real-file tests are skipped in normal runs; both passed with Seven Powers.
- AppFlowy PDF compatibility test generated a PDF containing heading, bold
  text and an embedded local image. PDF library remains 3.12.0.
- Full-page regression covers loading layout, contents selection and Back.
  Real-app testing caught and fixed a footer loader that initially hid the body.

### Sampled process memory

`ps` RSS values converted from KiB to MiB; `vmmap` physical-footprint values
reported separately. These are whole-app readings, not reader-only heap sizes.

| Stage | Resident memory | Physical footprint |
| --- | ---: | ---: |
| Fresh login, before picker | 103.5 MiB | not sampled |
| Seven Powers cover | 170.4 MiB | 126.4 MiB |
| Chapter One after resizing | 193.4 MiB | 171.5 MiB |
| Back to login after scrolling | 159.7 MiB | 115.4 MiB |

Peak physical footprint reported by macOS during that process lifetime:
210.1 MiB. Idle CPU samples were 0%. Memory dropped on closing, but did not
immediately return to fresh-login RSS; one session is insufficient for a
long-run leak conclusion. No separate WebView process is used by this reader.

## Tablet assessment and remaining limits

Promising for ordinary text-oriented EPUBs: no second browser engine, lazy
widgets, bounded decoded images and background parsing. Android shares the
Dart renderer, but GPU, allocator, CPU and OS memory behavior differ; the Mac
numbers must not be quoted as Android requirements or guarantees.

Book content and paragraph structures remain whole-book in memory. For very
large illustrated books, incremental chapter loading may be a better direction.
This renderer also has less complete EPUB CSS/layout support than a browser;
SVG/fixed-layout/media-heavy EPUBs need separate evaluation. It is scrolling,
not a paginated reader. Persistent resume and cross-engine CFI interoperability
are not yet implemented/verified. Chapter-summary source-link storage and
matching are deliberately outside this change.

Recommendation: try this build on the tablet next. Compare EPUB.js only if
memory, rendering fidelity, or precise navigation fails that test. A second
engine implementation is not needed merely to resolve the dependency conflict.

## Pagination follow-up

NX Books now opts into the native renderer's paginated mode. Next/previous
buttons, horizontal swipes and left/right or Page Up/Down keys turn pages.
The displayed page count is for the current chapter and recalculates with font
size, window dimensions and system text scaling. Page transitions are instant,
without a page-curl animation.

Pagination measures Flutter's actual laid-out text lines and image rectangles;
it does not slice text at fixed character counts or clip at arbitrary screen
heights. Images scale within the page. A paragraph/text-run/character anchor
keeps the current passage on a visible page after reflow. It is an in-session
anchor, not a new persisted KGQL source-link format.

Only the current chapter's widget tree is mounted; page turns reuse its layout.
Changing chapters releases its decoded image cache entries. This is a different
memory tradeoff from the earlier lazy-paragraph scrolling mode: potentially
more widgets per chapter, but no entire-book widget tree or browser process.
The EPUB data itself is still loaded eagerly. Very large single-chapter or
complex fixed-layout books remain a limitation; oversize unbreakable items
produce a clear error instead of silently cutting content.

Validation: 84 app tests and 26 reader tests pass. Tests cover contiguous page
ranges, unsplit lines/images, nested HTML WidgetSpans, font/window reflow that
retains the visible source passage, keyboard/swipe input, and forward/backward
chapter boundaries. The optional Seven Powers test paginates all 24 contents
entries and visits each generated page without rendering errors.

Installed and visually checked the signed macOS release. Seven Powers Chapter 1
showed 37 pages at the initial font/window size, 39 after increasing the font,
and 21 after enlarging the window. Restoring the window returned to page 2 of
39 with the same passage visible. Cover scaling, chapter selection and next-page
rendering also passed the installed-app check. Android debug build succeeds;
physical tablet pagination/performance has not yet been measured. The memory
figures above describe the earlier scrolling build, not this paginated build.

## Login and internal-link follow-up

macOS now uses the existing Apple development team and Keychain capability
instead of ad-hoc app signing. The user confirmed successful hosted login.
The temporary local EPUB opener and its user-selected-file entitlement have
been removed; books are opened through their normal cached attachment route.

Internal EPUB links resolve relative to their source document, including nested
anchors, duplicate IDs in different files and percent-encoded fragments. They
jump directly to renderer positions rather than round-tripping generated CFIs.
The real Seven Powers test activates its in-book contents link to Chapter 1
and verifies the destination, then visits all 24 contents entries. App tests:
85 passed (two optional tests skipped in the ordinary run); reader tests: 27.

## Persistent resume

Book.epub_reading_position stores an EPUB-specific JSON position: versioned
renderer block/run/character location, attachment sha256, font size, UTC save
time. It is not a fixed page number or a cross-engine CFI. The file hash prevents
restoring a locator into a replaced attachment. A future renderer schema change
must version/migrate the locator rather than reinterpret its indices.

The renderer only exposes locations; the app reader only emits/accepts position
data. A separate account/backend-scoped repository persists each change locally
and coalesces authenticated KGQL writes in a durable latest-value outbox. It
retries after failure and on normal library synchronization. Loading waits at
most three seconds for a remote position before using local data. Background
progress failures do not block library sync. A newer server timestamp supersedes
an older pending offline position; simultaneous devices use last-write-wins,
not server-side compare-and-swap (device clocks should be reasonably correct).

Tests cover restart within a long paragraph, malformed locator versions, durable
offline retry, in-flight page turns, account isolation and newer remote progress.
88 app tests and 28 renderer tests pass. Hetzner Book type 59 has the additive
attribute; live Seven Powers model 4427 accepted progress through the installed
Mac app and authenticated KGQL API. No server restart was required.
