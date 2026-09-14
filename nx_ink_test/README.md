# NX Ink Test

Minimal, native-only Android experiment in the Canvas worktree. Package:
`com.nexus.inktest`; app name: **NX Ink Test**. It installs alongside NX Canvas.

The Activity directly instantiates the tablet firmware's `com.xrz.NoteView`.
The vendor widget owns all pen handling, drawing, buffering, and refresh
scheduling. The app adds only a title, Clear button, and Info button. There is
no Flutter dependency, custom renderer, MethodChannel, JSON, database, bitmap
copy loop, application pen-event listener, or network permission.

This tests a different level of the firmware API from NX Canvas's previous
`HandwrittenClient` adapter: the vendor's complete drawing widget rather than
our own drawing code around its low-level service. Missing or inaccessible
APIs are reported visibly; no fallback is silently substituted. No system
settings or API-access exemptions are changed.

Write directly with the physical stylus. Compare with the device's built-in
notes app. Tap Info after writing to inspect the vendor widget version and
record count. Clear removes this test page's ink. Drawings are temporary and
are not saved; existing NX Canvas drawings are not accessed.

Build using JDK 17+ (21 tested) and Android SDK 36:

```sh
./gradlew assembleRelease
adb install -r app/build/outputs/apk/release/app-release.apk
adb shell am start -n com.nexus.inktest/.MainActivity
```

The release is signed with the local development key for sideloading but is
not debuggable. This project contains no device firmware or third-party SDK
source. The API signatures were inspected from the connected tablet's own
framework library.

## Device result

Tested as release v0.1 (build 1) on the connected RUERTU Android 11 tablet.
The firmware widget loaded successfully and displayed physical stylus strokes.
The user tested live handwriting and reported: “its flawless, perfect!”

This is the known-good latency baseline. Preserve this project unchanged while
integrating the firmware NoteView into NX Canvas separately. Do not replace it
with the previous HandwrittenClient + application-managed SurfaceView copy loop.
Recheck pen responsiveness after adding stroke extraction, saved-data restore,
coordinate transforms, and Flutter hosting; their performance is not established
by this isolated test.
