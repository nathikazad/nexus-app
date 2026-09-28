# Nexus Android OIDC transport

Vendored from pub.dev oidc_android 2.0.1; original LICENSE retained. Used by
Cards and Docs through explicit path overrides. Apple and web packages are
unchanged. Shared NX Auth prefers Chrome and uses a five-minute native deadline.
Chrome is optional: use another Custom Tabs provider or the default browser
when it is absent. Older Chrome versions use the redirect receiver fallback.

Changes: honor preferredBrowserPackages as preferences, allow browser fallback, catch
launch failures, reject fallback redirects with wrong path/state, share accepted
redirect foreground return, and fail/return on timeout. Cards uses
FlutterFragmentActivity and Docs AudioServiceFragmentActivity so AndroidX Auth
Tab delivers a result and closes itself; audio/drawing hooks remain in place.

PKCE, nonce, signature and complete OIDC response validation remain upstream in
Dart. A process-death redirect without a pending flow is never accepted.

Tests: run :oidc_android:testDebugUnitTest from an app Gradle build. Review the
small Kotlin changes against upstream before replacing this fork on upgrades.
