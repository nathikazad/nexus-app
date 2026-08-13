## iOS installation policy

- All physical iOS installations must be Shorebird-enabled.
- Never install an iOS release using `flutter run --release` or `flutter install`.
- If the device does not already have a compatible Shorebird base, create one with `shorebird release ios` and install that build.
- For Dart-only changes against an installed compatible Shorebird base, use `shorebird patch ios`.
- Before patching, verify the installed build number has a corresponding Shorebird release.
- Native dependency, entitlement, plist, Pod, or engine changes require a new Shorebird release rather than a patch.
- `nx_cards` AI study and `nx_notes` live conversations require `OPENAI_API_KEY` at compile time. The Shorebird wrapper validates the Git-ignored `nx_live_agent/.env` and passes `--dart-define-from-file=../nx_live_agent/.env` automatically for every release or patch; verify the key exists and never commit it.

## macOS installation policy

- Build `nx_notes` from its app directory with `flutter build macos --release --dart-define-from-file=../nx_live_agent/.env`. Verify `OPENAI_API_KEY` exists in the ignored env file without printing or committing its value.
- Live voice requires the release app to retain `com.apple.security.network.client`, `com.apple.security.network.server`, and `com.apple.security.device.audio-input` entitlements. An HTTPS response alone does not prove voice works; without the server entitlement, the WebRTC data channel can time out while connecting.
- Before installing, run `codesign --verify --deep --strict "build/macos/Build/Products/Release/Nexus Notes.app"`. Flutter incremental builds can occasionally modify `App.framework` after it was signed. If verification identifies that framework, re-sign `App.framework`, then re-sign the outer app with `macos/Runner/Release.entitlements`, and verify the whole bundle again. Do not install a bundle that still fails verification.
- Update the existing `/Applications/Nexus Notes.app` with a recoverable staged replacement: stop the running app, move the installed bundle into a narrowly scoped temporary backup directory, copy the verified release bundle with `ditto`, and restore the backup if copying or validation fails.
- Verify the installed bundle itself with `codesign --verify --deep --strict "/Applications/Nexus Notes.app"`, confirm its signed entitlements include `com.apple.security.network.server`, and then launch it.
- For changes involving live voice, complete a functional smoke test in the installed app. A successful test must advance from `CONNECTING` to `LISTENING`; merely launching the app or finding the compiled credential is insufficient.
