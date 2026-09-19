import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas_core/drawing.dart';
import 'package:nx_docs/documents/editor/nx_appflowy_blocks.dart';

void main() {
  testWidgets(
    'end picker appends after a canvas without replacing it',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = nxCanvasNode();
      final editor = EditorState(
        document: Document(
          root: Node(type: 'page', children: [original]),
        ),
      );
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
      final menuState = tester.state(find.byType(NxSlashMenuOverlay));
      // Keyboard appearance and window resizing rebuild the overlay without
      // starting a new picker session or losing its insertion point.
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1000, 800);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpAndSettle();
      tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(NxSlashMenuOverlay)), same(menuState));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NxSlashMenuOverlay),
          matching: find.text('Canvas'),
        ),
      );
      await tester.pumpAndSettle();
      expect(editor.document.root.children.length, 2);
      expect(editor.document.root.children.first, same(original));
      expect(editor.document.root.children.last.type, nxCanvasBlockType);
      expect(find.byType(NxSlashMenuOverlay), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(NxSlashMenuOverlay), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(NxSlashMenuOverlay), findsNothing);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(990, 10));
      await tester.pumpAndSettle();
      expect(find.byType(NxSlashMenuOverlay), findsNothing);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      // Keep the root overlay alive while removing the document's owner.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NxSlashMenuOverlay), findsNothing);
      expect(tester.takeException(), isNull);
      editor.dispose();
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

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
            body: NxElementPickerScope(
              child: AppFlowyEditor(
                editorState: editor,
                blockComponentBuilders: nxBlockComponentBuilders(),
              ),
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
      const channel = MethodChannel('nx_canvas/editor');
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
            body: NxElementPickerScope(
              child: AppFlowyEditor(
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
            body: NxElementPickerScope(
              child: AppFlowyEditor(
                editable: false,
                editorState: editor,
                blockComponentBuilders: nxBlockComponentBuilders(),
              ),
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
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    }),
  );
}
