# NX Flutter Ink Test

Minimal comparison with the known-good sibling `nx_ink_test` native Android app.
A static Flutter screen embeds the stock firmware `com.xrz.NoteView` directly
using hybrid composition. Native setup is the same: untouched black SimplePen,
6 physical pixels wide, input enabled. The widget owns its native input and
refresh threads. No subclass, drawing hooks, completed-stroke callbacks,
restored bitmap, document model, database, thumbnails, timers or custom channels.
There are no ink-related Flutter updates while writing. This app does not save.

Separate package `com.nexus.nx_flutter_ink_test`; NX Canvas and NX Ink Test are
unchanged. This is a latency experiment, not a full drawing app. Compare
physical stylus response to NX Ink Test; screen mirroring cannot measure it.

Build with `flutter build apk --release --target-platform android-arm64`.
The firmware API is loaded reflectively; unavailable devices display an error.
No firmware binaries, source libraries or compile-only stubs are included.
