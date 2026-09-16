## iOS installation policy

- Physical iOS installations must be Shorebird-enabled by default. The only
  exception is when the user explicitly asks for a debug installation for
  quick edits, hot reload, or rapid visual iteration; in that case, use
  `flutter run` on the requested physical device and keep the session alive.
- Never install an iOS release using `flutter run --release` or `flutter install`.
  The explicit debug/hot-reload exception above permits debug `flutter run`
  only; it does not permit a non-Shorebird release installation.
- If the device does not already have a compatible Shorebird base, create one with `shorebird release ios` and install that build.
- For Dart-only changes against an installed compatible Shorebird base, use `shorebird patch ios`.
- Before patching, verify the installed build number has a corresponding Shorebird release.
- Native dependency, entitlement, plist, Pod, or engine changes require a new Shorebird release rather than a patch.
- `nx_cards` AI study and `nx_docs` live conversations require `OPENAI_API_KEY` at compile time. The Shorebird wrapper validates the Git-ignored `nx_modules/nx_live_agent/.env` and passes `--dart-define-from-file=../nx_modules/nx_live_agent/.env` automatically for every release or patch; verify the key exists and never commit it.

## macOS installation policy

- Build `nx_docs` from its app directory with `flutter build macos --release --dart-define-from-file=../nx_modules/nx_live_agent/.env`. Verify `OPENAI_API_KEY` exists in the ignored env file without printing or committing its value.
- Live voice requires the release app to retain `com.apple.security.network.client`, `com.apple.security.network.server`, and `com.apple.security.device.audio-input` entitlements. An HTTPS response alone does not prove voice works; without the server entitlement, the WebRTC data channel can time out while connecting.
- Before installing, run `codesign --verify --deep --strict "build/macos/Build/Products/Release/Nx Docs.app"`. Flutter incremental builds can occasionally modify `App.framework` after it was signed. If verification identifies that framework, re-sign `App.framework`, then re-sign the outer app with `macos/Runner/Release.entitlements`, and verify the whole bundle again. Do not install a bundle that still fails verification.
- Update the existing `/Applications/Nx Docs.app` with a recoverable staged replacement: stop the running app, move the installed bundle into a narrowly scoped temporary backup directory, copy the verified release bundle with `ditto`, and restore the backup if copying or validation fails.
- On the first installation after the rename, treat the legacy `/Applications/Nexus Docs.app` (or older `/Applications/Nexus Notes.app`) as that existing bundle and move it into the same recoverable backup before installing `Nx Docs.app`. The bundle identifier is intentionally unchanged, so this is a filename migration rather than a second application identity.
- Verify the installed bundle itself with `codesign --verify --deep --strict "/Applications/Nx Docs.app"`, confirm its signed entitlements include `com.apple.security.network.server`, and then launch it.
- For changes involving live voice, complete a functional smoke test in the installed app. A successful test must advance from `CONNECTING` to `LISTENING`; merely launching the app or finding the compiled credential is insufficient.

## Worktree location and cleanup

- Create future Nexus worktrees under `~/Projects/Nexus-worktrees/<task>/mobile`,
  alongside the main checkout at `~/Projects/Nexus/mobile`.
- Use a short descriptive task name. Do not put worktrees inside the main Nexus
  checkout, Downloads, or temporary directories unless the user requests it.
- Use `git worktree add`, `move`, and `remove` so Git's worktree metadata stays
  correct. Before removing a completed worktree, commit and merge its intended
  changes into the main checkout, preserve unrelated local edits, and retain any
  useful ignored diagnostics or artifacts outside the worktree.

## Domain sessions

- Hypnosis, Cards, Docs and Books use NX Auth's selected domain. Identity alone
  is not data readiness: wait for `User.domainId` / `domainReadyProvider`.
- Send `X-Nexus-Domain-Id` on every data transport, including voice and GraphQL
  WebSocket connection payloads. Never infer a domain from a model type.
- Storage identity is logical server + user + domain + app. Preserve pending
  edits in their original partition; never adopt an old unscoped queue by guess.
- Bind clients and asynchronous work to their session. Domain switching must
  dispose the old sync/voice clients before new work starts.
- The server contract and current rollout status are documented in
  `../servers/docs/domain-sessions.md`. Other apps are outside this rollout;
  do not add compatibility fallbacks for them.

## NX Cards generation and imports

- Treat a card as content plus scheduling data. Copying text, tags, translations,
  or audio from a reference collection is not a complete card import.
- Prefer the normal card-creation path. Before a scripted or database import,
  inspect the current creation defaults in nx_cards/lib/browser/data/kgql/kgql_card_api.dart,
  `emptyScheduleJson` in nx_cards/lib/browser/data/kgql/kgql_card_mapper.dart,
  and `CardSchedule.initial` in nx_cards/lib/browser/data/models/memory.dart.
  Match these defaults rather than inventing a partial payload.
- New language cards need an explicit initial schedule with `from_language`,
  `to_language`, and `transliteration` enabled. The current format is version 3,
  algorithm `fsrs`; each cue starts with state `learning`, step 0, zero review
  and lapse counts, and null due date, last-reviewed time, stability, and
  difficulty. Include empty review history using the normal creation format.
  Missing schedules currently decode as disabled cues: Study can show those
  cards while Recall silently excludes them.
- Verify the intended user and personal/shared domain, model type, Language tag,
  and category tags (for example Word Category = Noun). Do not copy another
  person's schedules, review history, or learning progress. New cards normally
  start as `not_started` (Future), unsuspended; preserve the user's chosen status
  if explicitly specified. A Current/Future status is distinct from a cue's
  enabled flag and its New/Learning/Retained memory state.
- Content or audio updates must preserve existing schedules, review history,
  learning status, and deliberate cue settings. Restrict any repair to the
  identified defective records; do not reset progress or enable intentionally
  disabled cues in bulk. Imports must detect duplicates and target only the
  intended user/domain.
- Verify saved data and the app sync payload, including every expected recall
  cue. Then verify representative cards in both Study and Recall with matching
  filters. New cards are not due yet, and Future cards may be excluded by the
  normal Recall UI; test with an appropriate eligible card or automated fixture
  rather than changing real learning progress just to make a count nonzero.
  Record expected versus actual counts and distinguish eligibility from due
  status. Row counts, successful sync, or audio playback alone are insufficient.
- For importer/creation-code changes, add regression coverage proving that a new
  language card has enabled recall cues and enters the recall candidate list
  when its status and filters permit it. If device verification is unavailable,
  report that limit explicitly instead of claiming end-to-end verification.
