# Shared NX Canvas

`nx_canvas_core` contains the versioned editable ink model and preview renderer.
Both the standalone NX Canvas prototype and NX Docs depend on it. Their Android
source sets include `android/src/main/kotlin`, so the native editor stays the same
implementation tested on the ink tablet. It uses the tablet's firmware NoteView;
other devices can render drawing previews without that firmware.

NX Docs inserts an AppFlowy `nx_canvas` block with `canvas_id`, `title`,
`preview_height`, and `drawing` attributes. Drawing contains format/version,
strokes (points, pressure, width, color), viewport, and named Places. The preview
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
The standalone NX Canvas app is not required to use the NX Docs element.

Tests cover native geometry/orientation in the prototype, existing Flutter ink
and storage behavior, the Docs block/native handoff, read-only previews, and a
real Docs database restart with editable canvas JSON. Physical handwriting and
full server round trips still need device/account testing after installation.
