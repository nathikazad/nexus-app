import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/features/editor/nx_highlight_notes.dart';

void main() {
  testWidgets('reader mode shows highlight note without editing controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final editorState = EditorState(document: _highlightedDocument())
      ..editable = false;
    addTearDown(editorState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showNxHighlightNoteDialog(
                context,
                editorState,
                Selection.single(
                  path: const [0],
                  startOffset: 0,
                  endOffset: 16,
                ),
                noteId: 'note_1',
              ),
              child: const Text('Open highlight'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open highlight'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('highlight-note-reader')),
      findsOneWidget,
    );
    expect(
      find.text('A read-only note for the highlighted passage.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Delete note'), findsNothing);
  });

  testWidgets('edit mode keeps the highlight note editor', (tester) async {
    final editorState = EditorState(document: _highlightedDocument());
    addTearDown(editorState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showNxHighlightNoteDialog(
                context,
                editorState,
                Selection.single(
                  path: const [0],
                  startOffset: 0,
                  endOffset: 16,
                ),
                noteId: 'note_1',
              ),
              child: const Text('Open highlight'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open highlight'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Delete note'), findsOneWidget);
  });
}

Document _highlightedDocument() {
  return Document.fromJson(<String, dynamic>{
    'document': <String, dynamic>{
      'type': 'page',
      'data': <String, dynamic>{
        nxHighlightNotesDocumentAttribute: <String, dynamic>{
          'note_1': <String, dynamic>{
            nxHighlightNoteTextKey:
                'A read-only note for the highlighted passage.',
          },
        },
      },
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'paragraph',
          'data': <String, dynamic>{
            'delta': <Map<String, dynamic>>[
              <String, dynamic>{
                'insert': 'Highlighted text',
                'attributes': <String, dynamic>{
                  nxHighlightNoteIdAttribute: 'note_1',
                },
              },
            ],
          },
        },
      ],
    },
  });
}
