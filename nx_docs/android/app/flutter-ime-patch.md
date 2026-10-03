# Flutter IME lifecycle patch

Pinned embedding: `a10d8ac38de835021c8d2f920dbf50a920ccc030`.

On the Android 11 ink tablet, opening a native canvas with the keyboard visible
can deliver IME `onPrepare`, stop the Flutter host, and dispatch the final zero
inset while FlutterView is GONE, without ever delivering `onEnd`. Upstream's
callback keeps `animating=true` and consumes later insets indefinitely.

The source replacement in `src/main/java/io/flutter/plugin/editing/` retains
Flutter's callback ABI and active-window animation behavior. It cancels deferral
on host stop/view detach and applies insets directly while the view is hidden.
Animation identities prevent late callbacks from an interrupted animation from
finishing a newer animation. Attach/start/focus events request fresh insets.
There is no polling, reflection, logging, forced keyboard dismissal, or Dart
padding override in this fix.

`flutter-ime-patch.gradle.kts` removes only this callback and its nested classes
from the dependency artifact; app compilation supplies the patched source. All
other embedding classes and transitive dependencies remain supplied by Flutter.
The transform checks the embedding revision and fails on upgrades, requiring an
explicit rebase or removal once upstream handles lifecycle cancellation.

Run `:app:testDebugUnitTest --tests
io.flutter.plugin.editing.ImeSyncDeferringInsetsCallbackTest` in the Android
project, then verify keyboard -> canvas -> document repeatedly on the tablet.

To remove the patch: remove the applied Gradle script, replacement source and its
license, and patch-specific tests after verifying the upstream regression fix.
The accompanying LICENSE is Flutter's BSD license.
