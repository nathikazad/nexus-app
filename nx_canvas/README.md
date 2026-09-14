# NX Canvas

A standalone Flutter experiment for thinking with a stylus on one continuous,
unbounded canvas. It lives on the `Canvas` worktree branch and does not change
NX Docs or AppFlowy.

## Try it

```sh
flutter pub get
flutter run -d macos
```

Draw with a mouse or stylus. A finger pans; two fingers pinch to zoom. On Mac,
trackpad gestures pan and zoom, the mouse wheel zooms, and the Hand tool or a
right/middle-button drag pans. Stylus contacts draw; touch contacts received
while drawing are ignored to reduce palm interference. Physical tablet palm
rejection and pressure still need validation on the target hardware.

- Pen, four colors, and four thicknesses; stylus pressure affects line width.
- Partial eraser cuts intersected line geometry, including sparse segments and
  fast eraser movements. Surviving pieces remain editable ink.
- Lasso strokes, then drag inside their selection to rearrange ideas.
- Undo/redo changes ink. Back returns to earlier views without changing ink.
- Overview fits the drawing. Places save named positions and zoom levels.
- Changes save automatically; reopening restores the drawing and last view.
- P / E / L / H switch tools. Cmd/Ctrl+Z undoes; add Shift to redo.

## Persistence and future embedding

`lib/canvas/canvas_surface.dart` is a reusable widget driven by
`CanvasController`. It does not know about SQLite, documents, or app navigation.
`lib/canvas/drawing.dart` defines a Flutter-independent, versioned JSON format.
The app shell owns persistence; a future AppFlowy block can own the same JSON
and open the same canvas widget full-screen.

`CanvasStore` stores a single `prototype` row in the local `nx_canvas.sqlite`
database returned by sqflite's platform database directory. Its columns are:

| Column | Purpose |
| --- | --- |
| `id` | Canvas identity; currently one prototype canvas |
| `drawing_json` | Editable source: strokes, viewport, named places |
| `preview_png` | Regenerable 640×400 PNG thumbnail |
| `updated_at` | UTC save timestamp |

The source and thumbnail are saved in one SQLite transaction. The PNG is never
used to reconstruct ink. There is no server connection or database migration
in the existing Nexus applications.

```json
{
  "format": "nx-canvas",
  "version": 1,
  "strokes": [{
    "id": "stroke-1",
    "color": 4280827204,
    "width": 3.0,
    "points": [[100.0, 120.0, 0.5], [110.0, 124.0, 0.8]]
  }],
  "view": {"x": 0.0, "y": 0.0, "scale": 1.0},
  "places": []
}
```

Points are `[worldX, worldY, normalizedPressure]`. Coordinates remain independent
of screen size and zoom. Erasing splits strokes at geometric intersections;
there are no background-colored masks. A backend can eventually store this
JSON in a JSON/JSONB or text column, with the preview in a blob or asset store.
Unsupported format versions fail visibly without replacing the saved data.

Saves debounce by 250 ms after completed drawing/navigation operations, run in
sequence, and flush when the app loses focus or receives a supported exit
request. A save failure remains visible with a Retry action. Abrupt process
termination can lose the active stroke or pending debounce. Undo/redo and view
back stacks are session-local, while strokes, view, and places persist.

## Scope

One canvas, local SQLite persistence, native Mac/iOS/Android project targets.
No account, cloud sync, note editor, export workflow, history timeline, AI,
AppFlowy integration, or drawing library UI. The thumbnail currently fits all
ink; an embedded document preview can later use a separate chosen viewport.
The prototype redraws visible content from the stroke list and rewrites the
single JSON document on save; very large drawings will need spatial indexing,
chunked persistence, and performance profiling. Selection moves strokes;
resizing and copying selections are not included yet.

## Verification

```sh
flutter analyze
flutter test
flutter test integration_test/canvas_test.dart -d macos
flutter build macos --release
```

Unit/widget tests cover disk clipping, fast partial erase, grouped undo,
selection movement, separate navigation history, JSON compatibility, stylus
and touch routing, pinch anchoring, and SQLite reopen. The native Mac integration
test uses an isolated temporary database and exercises mouse drawing, partial
erasing, undo/redo, zoom, PNG persistence, and app-widget/database reopen.

## Ink rendering update (Android build 2)

Pointer moves repaint a separate live-ink layer without rebuilding the app
shell or repainting the completed drawing/grid. Completed ink remains behind
its own repaint boundary. Live points render directly without copying the
whole active stroke into an immutable model each frame. Thumbnail work waits
until an active drawing gesture ends. Tests verify that 100 pen samples leave
the background repaint boundary and shell untouched. This verifies reduced
rendering work, not a measured end-to-end stylus latency improvement; actual
pen-to-display delay still needs comparison on the tablet.

## Native handwriting trial (Android build 3)

Android starts with the native pen backend enabled. The lightning-bolt button
switches back to Flutter ink. Pen mode uses a hybrid-composed Android
SurfaceView, placed below the toolbar, and the tablet's own
`com.xrz.HandwrittenClient` service. The native ink buffer receives immediate
pen segments and localized handwriting refresh requests. On pen-up, normalized
pressure and world-space points return to Dart as one undoable stroke and save
through the existing SQLite path. No vendor drawing files are used as storage.

Choose Hand for panning/pinch zoom, Erase for partial erasing, or Lasso to move
ink; these use the existing Flutter surface. Returning to Pen restores the
native view at the same coordinates and zoom. Native finger navigation and the
physical eraser end are not implemented in this initial trial. Help and Places
also temporarily release native input. Native mode currently uses a plain
background instead of the dotted Flutter grid.

The implementation uses reflective vendor method calls with normal app
permissions. It does not change system settings, grant permissions, or enable
hidden-API exemptions. Missing/denied APIs show an error and fall back to
Flutter. Vendor compatibility is not assumed on other devices. The tested
RUERTU Android 11 tablet accepted the connection and reported handwriting
service version `v1.2.10`; physical stylus input produced editable stroke
callbacks. User comparison is still needed to assess visible latency.

The device API signatures were inspected locally. The independent open-source
project https://github.com/imedwei/inksdk provides useful documentation of the
same XRZ service. No SDK source or device firmware is included in the app.
Local inspection artifacts and the screen-mirror wrapper live in ignored
`diagnostics/` only.

### Live stroke correction (Android build 4)

Build 3 relied on the vendor overlay for live ink and posted the ordinary
SurfaceView only after pen-up. On this tablet the user observed ink appearing
only on pen-up despite successful vendor callbacks. Build 4 also draws each
incoming segment into the host bitmap and posts that bitmap once per display
frame while the pen is down. SQLite still receives one completed editable
stroke at pen-up. `NxNativeInk` logs `Live surface frame ... penDown=true` to
distinguish live surface submissions from final-stroke capture. A successful
submission does not itself prove the physical e-ink panel has refreshed.

### Refresh batching (Android build 5)

The user confirmed build 4 displays ink before pen-up, but still too slowly.
One observed long stroke submitted 24 live frames in roughly two seconds.
Build 5 accumulates dirty rectangles and makes at most one vendor refresh
request per scheduled display frame instead of a Binder request per input
sample. It caches the native Canvas/method and requests dirty-region surface
updates. Stroke logs also record aggregate surface submission time. This is a
performance experiment; it does not yet establish acceptable physical latency.

## Firmware NoteView integration (Android build 6)

The separate `../nx_ink_test` app hosted the tablet's stock `com.xrz.NoteView`
without Flutter or a custom renderer. The user reported its physical pen
latency as “flawless, perfect.” That app remains unchanged as the baseline.

Build 6 replaces the slow HandwrittenClient/SurfaceView implementation with
that same NoteView, hosted in NX Canvas's native pen area. A small subclass
calls the firmware's original drawing method and queues only completed record
references. The firmware retains its own input, drawing thread and display
refresh behavior. Completed records are converted on the Android main thread
into editable world-space points and passed to the existing Dart controller
and SQLite store. There is no custom live renderer or per-point platform-channel
traffic. Native stroke acknowledgments never cause a full-scene echo; foreground
restoration is limited to initial mounting, resizing, navigation and document
edits. Style changes update the pen alone.

Delivery identifiers prevent duplicate imports, including a pending pen-up
returned during native view disposal. Tool changes retain completed ink;
Hand/pinch zoom, toolbar erasing, lasso and navigation still use Flutter.
The physical eraser end is not supported in this trial; use the Erase tool.
Firmware pen curves are stored as normalized sampled polylines, so restored
edge smoothing/pressure appearance can differ slightly from the vendor's live
rendering. The database contains editable data plus a PNG preview, not only an
image. Storage remains local SQLite in this prototype.

`android/vendor-api` contains only handwritten compile-time API declarations,
not firmware or third-party implementation code. It is `compileOnly`: APK dex
inspection confirms no `com.xrz` implementation classes are bundled. Devices
without this firmware fall back to the Flutter surface.

Validation: release ARM64 APK builds; analysis and 12 automated tests pass.
Tests cover no scene echo on native completion, style-only updates, undo scene
restoration, final delivery at disposal, duplicate delivery after undo, editable
stroke round trips, partial erasing, and SQLite reopen. Build 6 was superseded by build 7 before installation.

## Two erasers (Android build 7)

The toolbar now has Rub eraser (E) and Region eraser (R). Rub removes touched
parts continuously. Region previews a red, automatically closed freehand loop;
lifting the pen removes the portions inside it and preserves the outside parts
of crossing strokes. The loop can be circular or any other shape. A tap or
straight line does nothing; cancellation leaves the drawing intact. Either
operation is one undo step, and surviving fragments remain editable and save
through the same versioned JSON/SQLite format. Both erasers currently use the
Flutter editing surface; returning to Pen restores the fast firmware widget.

Analysis and all 16 tests pass, including sparse crossing segments, pressure
interpolation, contained ink, boundary dots, misses, concave loops, undo/redo,
and cancellation. Build 7 includes the build 6 native integration. Build 7 was installed successfully on the tablet; startup logs confirm the
firmware widget loaded and restored all 35 saved strokes. Physical handwriting
latency and eraser feel await user testing.

## Separate native handwriting screen (Android build 8)

The user reported build 7 was still too slow. Build 8 removes the embedded
Flutter platform view from the active UI. Android opens a plain Activity with
the unmodified firmware NoteView, matching the NX Ink Test layout approach.
There is no subclass, completed-record callback, polling, platform-channel
traffic, or Flutter UI rebuilding while writing. Saved ink is restored once
when the native view is laid out. This isolates composition/bridge overhead;
physical latency remains an empirical test, not an assumed fix.

Done returns to the Flutter canvas for both erasers, selection and navigation.
Tap Pen or the lightning button to reopen handwriting. Completed native records
are captured on Done or activity pause to an atomic local handoff journal.
Dart imports them as editable strokes, flushes SQLite, then acknowledges the
journal. Stable source IDs avoid duplicate recovery if SQLite was saved but
acknowledgment was interrupted. The native input snapshot and handoff files
stay in app-private storage, not Downloads. The native screen locks its launch
orientation to keep the experiment's coordinate mapping stable.

This experiment deliberately does not continuously checkpoint while drawing:
a crash or power loss during an uninterrupted session can lose strokes since
the last pause/Done. The firmware's own record buffer is limited to about 4,000
strokes per session. Physical eraser hardware remains unsupported; use Done
and either toolbar eraser. These are prototype limits to resolve after the
latency path is validated.

Validation: release ARM64 build, clean analysis, and all 17 tests pass, including
journal redelivery across a drawing reopen. The NX Ink Test baseline is unchanged.

## Pure-black pen comparison (Android build 9)

The user reported build 8 was worse, while reopening the unchanged NX Ink Test
confirmed the baseline was still fast. Build 9 makes one functional change to
the build 8 editor: it leaves SimplePen's default pure-black paint untouched
instead of applying the selected graphite/palette color. The native layout,
width, saved foreground restoration and exit-only persistence are unchanged.
The screen title identifies this as the Black ink test. All new handwriting in
this trial is black, regardless of the palette selection on the canvas screen.
This is a controlled test of the ink-color difference, not a verified diagnosis.
Eight completed strokes from build 8 were checkpointed when the baseline was
opened, before replacing the app. The build 9 startup imports pending strokes
through the existing recovery path.

## Black ink embedded in the main canvas (Android build 10)

The user confirmed build 9 was perfect. Build 10 returns the firmware widget to
the main canvas while retaining its untouched default black paint. Pen no
longer launches another Activity, and the diagnostic lightning/Done flow is
removed from the main UI. This tablet shows only the black ink choice. Help,
Places and the pen-width popup temporarily release the native view so its pen
input cannot draw behind those controls. Both erasers and navigation remain in
the same workspace. Completed strokes again autosave through the pen-up bridge;
own-stroke acknowledgments do not redraw the native foreground.

Startup recovers any pending strokes from the separate-screen trial before
mounting the embedded widget. The old diagnostic Activity remains in source
for comparison. Build 10 was installed and startup logs confirmed native ink
loaded and restored 12 saved strokes. Screen mirroring confirms the canvas
with its toolbar is displayed in MainActivity. Physical latency in this
embedded black-ink configuration awaits user confirmation.

Clean analysis and the 17 previous tests pass; the additional Android UI test
verifies switching from eraser back to Pen mounts an embedded view without
opening the separate editor and exposes only black ink.

## Flutter gallery + complete native canvas (Android build 11)

NX Canvas now opens a Flutter gallery. Existing prototype data migrates in place
to a named tile; New drawing creates an independent canvas, and tiles can be
renamed. Tapping a tile launches the native Android editor in the same app.
Back / Drawings checkpoints the editor, returns its full editable document to
Flutter, saves it and a PNG thumbnail into SQLite, and refreshes the matching
tile. The database's version-2 migration adds titles without replacing existing
drawing data. Non-Android builds retain the Flutter editing screen per tile.

The entire Android drawing screen is native: Pen, Rub erase, Region erase,
Lasso / move, Hand, width, undo/redo, previous view, overview, saved places, and
zoom. Pen uses stock SimplePen with its untouched pure-black paint; rub and
region erasers use the firmware's Rubber and RegionRubber. Only navigation and
selection use a normal Android custom view. There is no Flutter drawing surface
or live ink callback. Completed vendor records are incorporated into the native
editable model when a control is used or the activity pauses/exits. Each gesture
is a separate undo step. Stroke sampling, pressure and world-space coordinates
remain compatible with the nx-canvas v1 drawing format.

Native changes are atomically checkpointed to an app-private document journal
on toolbar/navigation actions and pause/back. The journal includes the drawing
ID and a save token. Flutter acknowledges it only after SQLite and the preview
are saved; interrupted returns recover the correct tile on next launch. Legacy
stroke journals from the earlier trial also migrate. Uninterrupted handwriting
still uses the firmware's finite record buffer (about 4,000 strokes); this
prototype does not do periodic work on the live drawing thread.

Validation: 20 Flutter tests pass, including SQLite v1 migration, independent
canvas reopen/rename, full native document replacement, and recovery retry.
Six JVM tests validate native rub/region clipping, pressure preservation,
concave regions, undo/redo, lasso movement, view history, and format roundtrip.
Static analysis is clean and the release ARM64 APK builds. Build 11 was
installed successfully. Screen-mirror checks verified the migrated First canvas
tile, opening its native toolbar, returning to the gallery, and reopening the
drawing. The user is testing physical drawing/eraser response on the tablet.

### Native editor update (build 12)

- Convert firmware panel-local record points using `NoteView.getAbsoluteRotation()`
  before density/viewport conversion. This matches the firmware's
  `generatePenPointForView`; it prevents new ink rotating on Hand/save.
  Existing saved coordinates are preserved, since older documents can mix
  strokes from different input paths and cannot be safely rotated wholesale.
- Magnify: select it, then tap an area to zoom 2× around that point.
  Previous view restores the preceding view. Hand still pans/pinches.
- Pen width controls new pen strokes. Lasso / move selects whole intersecting
  strokes with a stylus loop, then moves them by dragging inside the selection.
- Standard Android stylus button/eraser motion signals temporarily select the
  stock RegionRubber, restoring the toolbar tool when released. No live drawing
  callbacks or Flutter bridge were added. Physical button delivery still needs
  validation on this tablet; its vendor-specific key events may differ.
- Native regression tests cover all four panel rotations, density/zoom mapping,
  and magnifier anchor/history behavior.

### Native foreground orientation (build 13)

Build 12 corrected record import but missed foreground export. Firmware
`Painter.drawBitmap` in scale mode ignores its rotation argument and directly
copies/scales the supplied bitmap into the panel canvas. Render foregrounds in
panel coordinates with swapped dimensions for quarter turns, using the inverse
of record import. This keeps Pen, Hand, Lasso and thumbnails in the same world
orientation. The round-trip regression includes non-square canvases, corners,
and asymmetric points at all four rotations.

### Tool switching (build 14)

Pen/Rub/Region changes and pen-width changes keep the native framebuffer instead
of rebuilding and reloading it. Foreground reloads invoke the vendor's screen
refresh path; `NoteView.onInputTouch` rejects points for 1000 ms after a background
update. Hand/Lasso/Magnify changes skip the 100 ms firmware drain window and do
not write unchanged documents. Record getters are resolved once per record,
not three times per point. Native-to-editing transitions still capture ink;
returning to ink after editing still rebuilds the foreground for correctness.

### Initial foreground lifecycle (build 15)

Wait for NoteView's surfaceChanged callbacks to complete before the initial
foreground render. The previous layout listener could read the default rotation
before the vendor initialized panel orientation/buffers, causing a quarter-turn
on reopen until Overview redrew it. Uses a posted surface callback, not a timed
delay, and leaves later tool-switch behavior unchanged. The native unit suite
covers geometry; opening-time behavior requires verification on the tablet.

### Vendor surface access (build 16)

Build 15 failed on device because NoteView extends vendor HandwrittenView,
not Android SurfaceView. Obtain its public getHolder() via reflection and use
SurfaceHolder.Callback without casting the widget. Correct the compile-only
NoteView stub to View so it no longer implies that invalid superclass.
Release build and native unit suite pass; device opening still needs a physical
tap because mirrored clicks are not reaching the app in this session.

### Accepted tablet build

Build 16 was confirmed working by the user after the vendor surface access fix.
The native geometry suite has 10 passing tests. Flutter gallery/storage tests
were previously verified (20 tests). The native and minimal Flutter ink test
apps are retained alongside this prototype for performance comparisons.
