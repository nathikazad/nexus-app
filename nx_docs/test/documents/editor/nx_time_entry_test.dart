import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/documents/editor/nx_appflowy_blocks.dart';

void main() {
  test('time and rich text survive document JSON round trip', () {
    final node = nxTimeEntryNode(
      time: const TimeOfDay(hour: 9, minute: 5),
      text: 'Morning walk',
    );
    final doc = Document(
      root: Node(type: 'page', children: [node]),
    );
    final restored = Document.fromJson(doc.toJson()).root.children.single;
    expect(restored.type, nxTimeEntryBlockType);
    expect(restored.attributes['time'], '09:05');
    expect(restored.delta!.toPlainText(), 'Morning walk');
    expect(nxPlainTextForCustomNode(restored), '09:05 Morning walk');
  });

  for (final journal in [false, true]) {
    testWidgets('time entry insertion availability: journal=$journal', (
      tester,
    ) async {
      final editor = EditorState(document: Document.blank());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NxElementPickerScope(
              child: AppFlowyEditor(
                editorState: editor,
                blockComponentBuilders: nxBlockComponentBuilders(),
                footer: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => appendNxDocumentElement(
                      context,
                      editor,
                      isJournalEntry: journal,
                      searchLinkableModels:
                          ({required modelType, required query}) async => [],
                      createLinkedDocument: (_) async =>
                          throw UnimplementedError(),
                      onLinkableModelSelected: (_, __) async {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      // Search makes the item visible even in the compact picker.
      await tester.enterText(find.byType(TextField).last, 'Time entry');
      await tester.pumpAndSettle();
      expect(find.text('Time entry'), journal ? findsWidgets : findsOneWidget);
      if (journal) {
        await tester.tap(find.text('Time entry').last);
        await tester.pumpAndSettle();
        final node = editor.document.root.children.last;
        expect(node.type, nxTimeEntryBlockType);
        await editor.apply(
          editor.transaction..insertText(node, 0, 'A moment to remember'),
        );
        await tester.pumpAndSettle();
        expect(node.delta!.toPlainText(), 'A moment to remember');
        await tester.tap(find.byTooltip('Change entry time'));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
