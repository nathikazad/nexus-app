## iOS installation policy

- All physical iOS installations must be Shorebird-enabled.
- Never install an iOS release using `flutter run --release` or `flutter install`.
- If the device does not already have a compatible Shorebird base, create one with `shorebird release ios` and install that build.
- For Dart-only changes against an installed compatible Shorebird base, use `shorebird patch ios`.
- Before patching, verify the installed build number has a corresponding Shorebird release.
- Native dependency, entitlement, plist, Pod, or engine changes require a new Shorebird release rather than a patch.
- `nx_notes` live conversations require `OPENAI_API_KEY` at compile time. Use the Git-ignored `nx_live_agent/.env` with `--dart-define-from-file=../nx_live_agent/.env` for every Shorebird release or patch; verify the key exists and never commit it.
