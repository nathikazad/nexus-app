import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas_core/drawing.dart';
import 'package:nx_docs/documents/editor/nx_appflowy_blocks.dart';

void main() {
  testWidgets(
    'slash menu retains insertion position when it takes focus',
    (tester) async {
      final editor = EditorState(
        document: Document(
          root: Node(type: 'page', children: [paragraphNode()]),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editor,
              blockComponentBuilders: nxBlockComponentBuilders(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      editor.selection = Selection.collapsed(Position(path: [0], offset: 0));
      editor.service.keyboardService?.enable();
      await tester.pumpAndSettle();
      final command = nxSlashCommand(
        searchLinkableModels: ({required modelType, required query}) async =>
            [],
        createLinkedDocument: (_) async => throw UnimplementedError(),
        onLinkableModelSelected: (_, __) async {},
      );
      expect(await command.handler(editor), isTrue);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canvas'));
      await tester.pumpAndSettle();
      expect(editor.document.root.children.first.type, nxCanvasBlockType);
      expect(find.byType(NxSlashMenuOverlay), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'canvas opens native editor and updates the same block',
    (tester) async {
      final node = nxCanvasNode();
      final editor = EditorState(
        document: Document(
          root: Node(type: 'page', children: [node, paragraphNode()]),
        ),
      );
      var saves = 0;
      var opens = 0;
      var acks = 0;
      const channel = MethodChannel('nx_docs/canvas');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'available':
            return true;
          case 'recoverDocument':
            return null;
          case 'openDocument':
            opens++;
            final args = Map<String, dynamic>.from(call.arguments as Map);
            expect(args['backLabel'], '‹ Document');
            return {
              'documentId': args['documentId'],
              'saveToken': 'token',
              'drawing': Drawing(
                strokes: [
                  InkStroke(
                    id: 'a',
                    points: [const Dot(0, 0), const Dot(20, 40)],
                    color: 0xff000000,
                    width: 3,
                  ),
                ],
              ).toJson(),
            };
          case 'ackDocument':
            acks++;
            expect(saves, 2);
            return true;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editor,
              blockComponentBuilders: nxBlockComponentBuilders(
                canvasDocumentId: '1',
                persistCanvasDocument: () async {
                  saves++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tap to draw'), findsOneWidget);
      await tester.tap(find.text('Tap to draw'));
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(acks, 1);
      expect((node.attributes['drawing'] as Map)['strokes'], hasLength(1));
      expect(find.text('Tap to draw'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'read-only canvas opens a zoomable preview without native editing',
    (tester) async {
      final node = nxCanvasNode();
      final editor = EditorState(
        document: Document(
          root: Node(type: 'page', children: [node]),
        ),
      )..editable = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFlowyEditor(
              editable: false,
              editorState: editor,
              blockComponentBuilders: nxBlockComponentBuilders(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empty canvas'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.iOS}),
  );
}
