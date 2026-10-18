# Mermaid in NX Docs

Insert a Mermaid block from the slash menu or end-of-document element picker.
Use **View**, to the left of **Edit**, to open a diagram-only view filling the app
window on desktop, tablet, and phone. Pinch or scroll to zoom, drag to pan, and use
Fit in the top-right corner to frame the whole diagram
again; Close returns to the document without changing its source.

Tap **Edit** or the preview to open the source editor and zoomable diagram. Wide windows show
source and preview side by side; narrow screens use Preview and Source tabs.
Save applies one undoable editor transaction. Close leaves the document unchanged.
Read-only documents allow viewing and source inspection, but not saving.

The native `mermaid_flutter` / `mermaid_core` 0.3 renderer works without WebViews,
JavaScript, network access, or server rendering. It is a Dart implementation of
Mermaid, not the official JavaScript engine: syntax support and layout can differ.
Invalid or unsupported source shows an error and does not overwrite the saved
block. Sources are limited to 30,000 characters. Rendering is cached by the widget
while mounted. Links in diagram source are not launched automatically.

Storage uses the existing AppFlowy `json_document` wrapper:

```json
{"type":"nx_mermaid","data":{"source":"flowchart TD\n A --> B","preview_height":420.0}}
```

No server schema migration is needed. The source is included in the editor's
plain-text extraction. Existing Excalidraw and other blocks are preserved.
Mermaid is supported in editing and highlight-only reading modes. Older clients
need an app update to display this custom block. There is no automatic conversion
of Markdown code fences into blocks; paste diagram source into the Mermaid editor.

Requires Dart 3.12 or newer. Tests:

```sh
flutter test test/documents/editor/nx_mermaid_test.dart test/documents/editor/document_editor_read_only_test.dart
```

`fixtures/data_problem.mmd` preserves the original flowchart supplied in the chat.
The tests exercise native rendering, phone/desktop layouts, JSON round-tripping,
source edits, undo, invalid input, read-only behavior, and insertion via the picker.

For visual QA, optionally set `MERMAID_CAPTURE` to an absolute PNG output path
and `MERMAID_CAPTURE_FONT` to an available TTF file when running the tests. Without
a loaded font, Flutter's test runner uses Ahem placeholder glyphs.
