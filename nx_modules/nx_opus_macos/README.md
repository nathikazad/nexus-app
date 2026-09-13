# Nexus macOS Opus

This platform-only Flutter plugin embeds a universal (arm64 + x86_64) dynamic
Opus framework through Swift Package Manager. Xcode embeds and signs it with
the app. `nx_voice` selects it only on macOS; other platforms retain their
existing loaders. No Homebrew or system library is needed at runtime.

Reproduce the binary with `bash tool/build.sh` from this directory. The script
downloads the official Opus 1.5.2 release, verifies its published SHA-256, builds
both architectures, and creates the XCFramework. It refuses to overwrite an
existing framework; move that directory aside before rebuilding. Temporary
build files are retained under the printed `/tmp/nexus-opus-build.*` directory.

Upstream source/checksum: https://opus-codec.org/release/stable/2024/04/12/libopus-1_5_2.html
The bundled library's BSD license is in `LICENSE`.

Apps using voice capture must separately declare `NSMicrophoneUsageDescription`
and the `com.apple.security.device.audio-input` sandbox entitlement. A library
load test is not a microphone smoke test: validate permission, PCM capture,
Opus packets, and cancellation in the signed installed app.
