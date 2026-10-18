import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/documents/editor/nx_appflowy_blocks.dart';

void main() {
  for (final width in [390.0, 1000.0]) {
    testWidgets('block delete visibility and undo at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final text = headingNode(level: 1, text: 'Heading');
      final visual = nxMermaidNode();
      final editor = EditorState(
        document: Document(
          root: Node(type: 'page', children: [text, visual]),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editor,
              editorStyle: EditorStyle.desktop(
                padding: const EdgeInsets.all(16),
              ),
              blockComponentBuilders: nxBlockComponentBuilders(),
              blockWrapper: (context, {required node, required child}) =>
                  NxBlockDeleteControl(
                    node: node,
                    editorState: editor,
                    enabled: true,
                    child: child,
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      expect(find.byTooltip('Delete block'), findsOneWidget);
      editor.selection = Selection.collapsed(Position(path: [0], offset: 1));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete block'), findsNWidgets(2));
      await tester.tap(find.byKey(ValueKey('delete-block-${text.id}')));
      await tester.pumpAndSettle();
      expect(editor.document.root.children, hasLength(1));
      expect(editor.document.root.children.single.type, nxMermaidBlockType);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        editor.document.root.children.first.delta!.toPlainText(),
        'Heading',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      await tester.pump(const Duration(seconds: 1));
    });
  }
  testWidgets(
    'last block deletion leaves an editable paragraph and undo restores it',
    (tester) async {
      final node = paragraphNode(text: 'Keep me');
      final editor = EditorState(
        document: Document(
          root: Node(type: 'page', children: [node]),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editor,
              editorStyle: EditorStyle.desktop(
                padding: const EdgeInsets.all(16),
              ),
              blockComponentBuilders: nxBlockComponentBuilders(),
              blockWrapper: (context, {required node, required child}) =>
                  NxBlockDeleteControl(
                    node: node,
                    editorState: editor,
                    enabled: true,
                    child: child,
                  ),
            ),
          ),
        ),
      );
      editor.selection = Selection.collapsed(Position(path: [0]));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete block'));
      await tester.pumpAndSettle();
      expect(editor.document.root.children.single.delta!.toPlainText(), '');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        editor.document.root.children.single.delta!.toPlainText(),
        'Keep me',
      );
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
