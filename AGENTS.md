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

For card creation, imports, and repairs, read [the card import skill](../servers/nexus/apps/nx_cards/skills/import-cards.md).
