# Install an iOS release directly

For updates to a paired iPhone on Wi-Fi, run from `mobile/`:

```sh
xcrun devicectl list devices
scripts/install_ios.sh nx_main --device YOUR_IPHONE_UDID -- --build-name 1.0.22 --build-number 2026100702
```

Use a standard Flutter SDK on PATH, or set `FLUTTER_BIN` to its executable.
The phone must be paired with Xcode, reachable, and unlocked for launch.
The existing project signing team and provisioning settings are retained.
Choose an appropriate build number; the example is not an automatic counter.
Preserve any existing flavor, target, and Dart defines after `--`.

The script builds `flutter build ios --release`, checks the signature, installs
`build/ios/iphoneos/Runner.app`, verifies the installed bundle ID/version/build,
and launches it. It prints build and installation timings and retains a JSON
verification receipt under `~/Projects/Nexus/tmp/ios-install/` (override with
`NEXUS_SCRATCH_DIR` if the canonical workspace scratch root differs).
It does not uninstall the existing app, clean caches, archive/export an IPA,
or publish to Shorebird. If launch is blocked by the lock screen, unlock and
open the app; the preceding installation may already have succeeded.

`--dry-run` checks arguments and required build configuration without building
or contacting the phone. Argument values are not printed because Dart defines
may contain secrets. Cards and Docs automatically use the ignored OpenAI env
file, validated by `ios_build_config.sh`, shared with the Shorebird wrapper.

Use debug/hot reload only when requested. It does not prevent later release
builds. Use `shorebird_apps.sh` only when explicitly requesting Shorebird:
Dart patches need a matching installed Shorebird base, and native or asset
changes need a full new base installation. Direct builds are not Shorebird bases.
