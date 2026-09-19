# Shared NX Canvas

`nx_canvas_core` exposes typed editor sessions and portable previews. The pure
Dart drawing model lives in `../nx_canvas_model`; the old drawing import remains
compatible. Android editing is packaged as a Flutter plugin backed by separate
model, engine, platform, firmware, rendering, recovery, diagnostics and editor
libraries. NX Docs and the example consume that plugin.

See [ARCHITECTURE.md](ARCHITECTURE.md) for module ownership, interfaces, lifecycle
contracts, extension points and tests. The native editor uses the tablet's firmware
NoteView; other devices can render drawing previews without that firmware.

NX Docs inserts an AppFlowy `nx_canvas` block with `canvas_id`, `title`,
`preview_height`, and `drawing` attributes. Drawing contains format/version,
strokes (points, pressure, width, color), viewport, optional board dimensions, and legacy named Places. The preview
is rendered locally from strokes, rather than storing a second image in JSON.
No server endpoint, database table, or schema migration is introduced.

The native editor returns a durable local journal keyed to a document/canvas
session. NX Docs applies it to that block, awaits its existing local document
save, then acknowledges the journal. Failed saves retain recovery data. A
matching block recovers it on mounting; opening another canvas is blocked until
that recovery is saved. Each editing launch gets a fresh persisted session ID,
so copied blocks do not share subsequent edits. Native live ink is not bridged
per point through Flutter.

On the tablet: enter Edit mode, insert `/canvas`, tap the preview, draw, and use
`‹ Document` to return. Other platforms/read-only modes open a zoomable preview.
No separate canvas app is required to use the NX Docs element.

Tests cover native geometry/orientation in the prototype, existing Flutter ink
and storage behavior, the Docs block/native handoff, read-only previews, and a
real Docs database restart with editable canvas JSON. Physical handwriting and
full server round trips still need device/account testing after installation.

The tablet editor navigates a board grid. Board width/height are initialized from
its drawing area once and stored in optional `boards: {width, height}` metadata;
old version-1 drawings remain compatible. A direction tap moves a quarter board; holding an arrow for 500 ms jumps once
to the adjacent aligned board. Releasing after a hold does not also move a quarter board. Directions extend through negative columns/rows. Ink stays in
one world coordinate system and may cross board boundaries. Populated boards
are derived from stroke segments (not visited views), so erasing removes empty
boards and undo restores them. The center dot shows the read-only populated-board overview and returns to editing
when a board is tapped. The arrow pad floats over the bottom-right of the canvas,
with coordinates at bottom-left. Navigation presses suspend firmware input so
operating the overlay does not intentionally create ink.
The stock NoteView still owns live pen/eraser processing; board guides and grid
previews are rendered only on navigation or editing transitions.

## Navigation, autosave, and diagnostics

The shared Android module owns stroke import, rendering, and local recovery:

- `RecordingNoteView` forwards admitted pen events directly to stock firmware.
  Transitions stop new contacts while allowing the current stroke to finish;
  no live points are queued, replayed or rewritten by the app. Its observation
  hook tracks down/up edges; its draw hook forwards completed record references.
  The tablet sends pen input outside Activity touch dispatch. `InkDrainGate`
  waits for completion of all outstanding strokes instead of sleeping 100 ms on
  every navigation action. A completion timeout leaves firmware ink intact.
- `TabletInputAdapter` decodes firmware records; `CanvasInputCoordinator` applies
  their normalized operations on a serial import worker. The UI receives immutable stroke lists. Weak
  identity deduplication avoids retaining records evicted by firmware.
- `InkSpatialIndex` indexes stroke bounds, including pressure-width margins and
  cross-board segments. `NativeTileRenderer` reuses unchanged 512-pixel ink tiles
  with a 32 MiB LRU budget. Rendering runs on one worker; obsolete results are
  discarded. Two panel buffers alternate only after the firmware receives the
  replacement; the currently submitted bitmap is never changed in place.
- `InkJournal` saves each completed operation through a FIFO IO executor.
  Checksummed delta frames serialize only changed stroke points, while retaining
  order, viewport, boards and Places. Periodic atomic compaction bounds replay
  cost. A torn trailing frame recovers the last durable revision. Save errors
  remain visible and retry; closing waits for the final durable snapshot.
- Native journal checkpoints protect edits during drawing. Docs imports and
  persists the final drawing on return, then acknowledges that recovery token.
  No full-document polling, AppFlowy updates, or document sync runs for live ink;
  canvas edits reach server sync after returning to Docs.
- `CanvasDiagnostics` records local JSONL spans for input, overview construction/drawing,
  board navigation, render/index/tile work, firmware calls, stroke import, journal
  saves and Docs persistence. A main-thread watchdog samples blocked stacks after
  500 ms, with worker stacks after 2 seconds. Frame, memory and GC samples provide
  context. Records contain counts/timings, not ink coordinates, titles or document IDs.
  Producers use a bounded nonblocking queue; a separate writer rotates four 2 MiB
  files in Android external app storage. No canvas diagnostics go to the server.

Capture after reproducing (tablet connected via ADB):

```sh
scripts/capture_canvas_diagnostics.sh /tmp/nx-canvas-diagnostics
```

The script collects retained JSONL, recent logcat, memory/frame summaries and
Android's last ANR/exit information. These are local support artifacts. Logs survive
app restarts but rotate as the app runs; capture soon after a freeze. Keep the release
mapping file with the APK if deeper decoding of optimized stack traces is necessary.

The firmware still imposes its own approximately one-second pen-input cooldown
following a foreground/background refresh. The app does not modify that private
firmware state. Coalescing rapid navigation reduces refreshes; this cooldown is
separate from the removed application timer.

### Regression checks

From `nx_docs/android`, with Java 21 configured:

```sh
./gradlew :canvas-model:testDebugUnitTest :canvas-engine:testDebugUnitTest :canvas-recovery:testDebugUnitTest :canvas-firmware:testDebugUnitTest :canvas-validation:testDebugUnitTest :canvas-validation:assembleDebug
adb install -r ../build/canvas-validation/outputs/apk/debug/canvas-validation-debug.apk
adb shell am instrument -w com.nexus.nx_canvas.validation/.CanvasInstrumentation
```

The validation app has a separate package and storage. It checks four-rotation
raster equivalence, tile/buffer reuse, actual firmware pen-up autosave, duplicate
completion handling, rapid navigation, and background journal writes. JVM tests
cover geometry, recovery after torn writes, failed compaction, token-specific
acknowledgment, navigation ordering, stroke barriers, cache eviction, and metrics.
Docs tests cover real database recovery, no document work during live ink, return-save ordering, and local
diagnostic payloads. Device validation also checks stalled main-thread capture and recovery.
