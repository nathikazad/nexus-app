# nx_cards

`nx_cards` helps a person collect knowledge and retain it through repeated
study. Its source tree tells that story before it explains the framework:

```text
main.dart
  -> app/            Flutter root, routes, theme, and shared layout
  -> browser/        finding cards through languages and books
     -> data/
        -> kgql/     fetch and translate the server representation
        -> models/   application-ready card vocabulary
     -> language/    language and word-category browsing
     -> card_list/   reusable card-list presentation
  -> study/          choosing and conducting a study session
     -> language/
        -> drawing/  handwriting and script recall
     -> session/     active review and recap
  -> scheduling/     deciding when a card returns and how it progresses
  -> tutor/          AI-assisted voice study
  -> sync/
     -> native/      Drift, local reads, and the mutation outbox
     -> remote/      upload and snapshot transport
  -> audio/          downloading and caching card audio
  -> account/        login and account access
  -> settings/       user-controlled application preferences
```

## Reading the application

Start at `main.dart`, then read `app/recall_app.dart` and `app/routes.dart` to
see how Recall starts and which page it opens. From there, follow the product
capability you care about. Each capability owns its production wiring: for
example, `browser/browser_providers.dart` selects the native or web library,
while `sync/sync_providers.dart` assembles Drift, the outbox, and remote sync.

Each capability exposes a same-named facade (`browser/browser.dart`,
`study/study.dart`, and so on). Code outside a capability should prefer that
facade over its implementation folders.

Inside `browser/data/`, information flows in one direction:

```text
kgql -> models -> browser and study UI
```

`models/` and scheduling policies are pure application vocabulary. `kgql/`
knows the server representation, while `sync/native/` knows Drift and the
outbox. UI code must not know either persistence representation.

## Runtime story

1. `account/` restores an authenticated or cached account.
2. `sync/` opens the account's local library and refreshes it when possible.
3. `browser/` presents language and book collections.
4. `study/` converts a collection and the person's choices into a session.
5. `scheduling/` records each answer and calculates the next review.
6. `tutor/` can conduct the same session through a live voice agent.

Native builds are local-first: Drift is the readable state and changes are
queued through the outbox. Web builds use the remote KGQL library directly.

## Tablet layouts

Library sources and language categories use `app/adaptive_card_grid.dart` to
choose one to three columns from the available window width and text scale.
Card lists use up to two wider columns. Content remains centered with a
1200 logical-pixel maximum width; settings and reading screens keep their
narrower readable widths.

Drawing practice stacks the reference above the canvas at every window width,
with scrolling on short screens to preserve writing space. The same drawing
controller survives resizing. Undo and Erase sit inside the drawing frame at the top right. Play, Hide/Show,
and Next sit below the frame.
Android drawing practice and writing recall open a separate opaque native
activity. Renderer selection checks firmware capabilities: NoteView first
(the existing RUERTU path), then the Bigme/XRZ HandwrittenClient service, then
a standard Android Canvas fallback. Bigme renders live segments directly into
the firmware canvas and updates the ordinary Android surface after pen-up.
Initialization failures select the fallback; Bigme runtime failures retain recorded
strokes in the fallback. Undo, clear, pause/resume and surface resize retain the
same controls. `NxCardsInk` logs selection and `NxCardsBigme` logs connection
or failure details. Build 20260936 was verified with physical pen input on a
Bigme HiBreak running Android 14, firmware Bigme_V1.020260716 (handwriting
service v1.4.0): connection, accepted pen callbacks and visible strokes were
confirmed, and the user reported it works perfectly. Other firmware versions
still need device testing; this is not a measured panel-latency result.
In native drawing practice, Previous stays to the left of Undo and is disabled
on the first card. It is not shown during recall.
The undocumented API is described by [inksdk](https://github.com/imedwei/inksdk);
no vendor binaries are bundled. The Bigme adapter uses AndroidHiddenApiBypass 6.1
to allow only `com.xrz` firmware APIs within the app process on Android 9+;
device-wide hidden-API settings remain unchanged. All drawing, Undo and Erase run inside Android without
Flutter composition. Audio bytes and individual recall saves use the existing
account-scoped Flutter repositories. Each recall answer is saved before the
native screen advances, and the existing recap opens when the session ends.
Other platforms keep the Flutter drawing screens.
Android tablet drawing practice (600dp smallest width and above) also reserves
the lower portion for a scrollable list of incoming Examples links, with the
full expression, transliteration, translation, and cached audio playback.
Multi-character prompts split that area into Examples and a narrow Characters
column. Character details and playback follow saved Contains links (including
through linked words), in reading order, with independent scrolling.
The Android bridge counts complete written letters (grapheme clusters), so
Tamil vowel signs and pulli stay attached. For example, வீடு shows வீ and டு,
and combined-letter cards are not replaced by their underlying components.
Android Study Draw also shows Previous beside Next after the first card.
Moving either way stops audio, clears the canvas, and reloads the selected
card's examples and character breakdown; writing recall stays forward-only.
The list changes with the practice card; phone and writing-recall layouts stay
unchanged.
Layout tests cover phone, tablet portrait/landscape, split-screen, and enlarged
text in the grid.

## OpenAI build configuration

AI study requires `OPENAI_API_KEY` from the Git-ignored
`../nx_modules/nx_live_agent/.env`. Release compilation fails when the Dart define is
missing. The shared Shorebird release and patch commands validate that file
and pass it automatically:

```text
# Run from mobile/.
scripts/shorebird_apps.sh release nx_cards
scripts/shorebird_apps.sh patch nx_cards
```

For a direct local Flutter run, pass
`--dart-define-from-file=../nx_modules/nx_live_agent/.env` explicitly.

## Boundaries

- `main.dart` stays a tiny entrypoint.
- Business policy does not import Flutter, Riverpod, KGQL, Drift, or HTTP.
- Each capability owns its providers and production adapters.
- `app/` contains only the Flutter root, routes, theme, and shared layout.
- Capability code imports another capability through its public facade.
- New generic top-level `core/`, `data/`, `domain/`, `features/`, or `utils/`
  roots are not allowed; top-level folders should name part of the product
  story. Technical folders such as `data/` are scoped beneath their owner.
- A folder represents a real cluster. Do not create a folder for one file.
- Prefer a cohesive module over a separate file for every enum, value object,
  or provider; split only when the resulting files are independently useful.
- Tests mirror the production capability tree.

## KGQL setup

After login, the app detects missing model types or required attributes and
presents an explicit setup action. Ordinary startup does not mutate schemas.

## Learning workflow and session setup

Cards store `future`, `practice`, or `recall`, shared across recall directions.
Future swipes into Practice, then Practice swipes into Recall. Current
and Past derive from the active card's per-direction recent recall score; an
untried active card is Current. Use the card detail selector to move backwards.

Practice opens a standalone Practice setup with Study sheet/Draw and a count.
Current/Past open Recall with Recall and AI tabs; both select Current/Past,
recall score and count. Only Recall shows the due-Past count. Future has no
session action. Practice and Recall retain separate setup preferences.

SQLite version 14 migrates legacy statuses without discarding history or pending
writes. The server rollout and migration are documented in
`../servers/nexus/apps/nx_cards/learning-workflow.md` relative to the mobile repo.
