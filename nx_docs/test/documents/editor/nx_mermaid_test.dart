import 'dart:io';
import 'package:flutter/services.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mermaid_flutter/mermaid_flutter.dart';
import 'package:nx_docs/documents/editor/mermaid_editor.dart';
import 'package:nx_docs/documents/editor/nx_appflowy_blocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = File(
    'test/documents/editor/fixtures/data_problem.mmd',
  ).readAsStringSync();

  test(
    'original flowchart renders and survives document JSON round trip',
    () async {
      final node = nxMermaidNode(source: source);
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            nxExcalidrawNode(),
            node,
            paragraphNode(text: 'Outline'),
          ],
        ),
      );
      final restored = Document.fromJson(document.toJson());
      expect(restored.root.children[1].attributes['source'], source);
      expect(nxPlainTextForCustomNode(restored.root.children[1]), source);
      final fontPath = Platform.environment['MERMAID_CAPTURE_FONT'];
      if (fontPath != null) {
        final font = FontLoader('trebuchet ms')
          ..addFont(
            Future.value(
              ByteData.sublistView(File(fontPath).readAsBytesSync()),
            ),
          );
        await font.load();
      }
      final bytes = await renderToPng(source, pixelRatio: 1);
      expect(bytes.length, greaterThan(1000));
      final capture = Platform.environment['MERMAID_CAPTURE'];
      if (capture != null) await File(capture).writeAsBytes(bytes);
    },
  );

  testWidgets(
    'native preview renders on narrow and wide screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(390, 844), const Size(1200, 900)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(home: NxMermaidEditor(source: source)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'View opens a full-window diagram with zoom, pan and reset',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [
        const Size(390, 844),
        const Size(820, 1180),
        const Size(1200, 900),
      ]) {
        tester.view.physicalSize = size;
        final node = nxMermaidNode(source: source);
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
                editorStyle: const EditorStyle.desktop(
                  padding: EdgeInsets.zero,
                ),
                blockComponentBuilders: nxBlockComponentBuilders(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.text('View')).dx,
          lessThan(tester.getCenter(find.text('Edit')).dx),
        );
        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();
        expect(find.byType(NxMermaidViewer), findsOneWidget);
        expect(find.byType(NxMermaidEditor), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(tester.getSize(find.byType(NxMermaidViewer)), size);
        final interactive = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        final transform = interactive.transformationController!;
        final fitted = transform.value.clone();
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pumpAndSettle();
        expect(
          transform.value.getMaxScaleOnAxis(),
          greaterThan(fitted.getMaxScaleOnAxis()),
        );
        final zoomed = transform.value.clone();
        await tester.drag(find.byType(InteractiveViewer), const Offset(60, 40));
        await tester.pumpAndSettle();
        expect(transform.value, isNot(zoomed));
        await tester.tap(find.text('Fit'));
        await tester.pumpAndSettle();
        expect(transform.value, fitted);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(NxMermaidViewer), findsNothing);
        expect(node.attributes['source'], source);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        editor.dispose();
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('edits save through AppFlowy and undo restores source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final node = nxMermaidNode();
    final editor = EditorState(
      document: Document(
        root: Node(
          type: 'page',
          children: [
            node,
            paragraphNode(text: 'Keep me'),
          ],
        ),
      ),
    );
    addTearDown(editor.dispose);
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
    await tester.tap(find.text('Mermaid'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mermaid-source')),
      'flowchart LR\n A[Changed] --> B[Done]',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(node.attributes['source'], contains('Changed'));
    expect(editor.document.root.children.last.delta!.toPlainText(), 'Keep me');
    editor.undoManager.undo();
    await tester.pumpAndSettle();
    expect(node.attributes['source'], defaultMermaidSource);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid source stays editable and cannot replace saved source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: NxMermaidEditor(source: defaultMermaidSource)),
    );
    await tester.enterText(
      find.byKey(const ValueKey('mermaid-source')),
      'not a diagram',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(NxMermaidEditor), findsOneWidget);
    expect(find.byKey(const ValueKey('mermaid-source')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only diagram exposes no Save action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: NxMermaidEditor(source: source, readOnly: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    if (find.text('Source').evaluate().isNotEmpty) {
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
    }
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mermaid-source')))
          .readOnly,
      isTrue,
    );
  });
  testWidgets('element picker inserts a Mermaid block after existing content', (
    tester,
  ) async {
    final editor = EditorState(
      document: Document(
        root: Node(
          type: 'page',
          children: [paragraphNode(text: 'Keep me')],
        ),
      ),
    );
    addTearDown(editor.dispose);
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
    await tester.enterText(
      find.descendant(
        of: find.byType(NxSlashMenuOverlay),
        matching: find.byType(TextField),
      ),
      'mermaid',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mermaid'));
    await tester.pumpAndSettle();
    expect(editor.document.root.children.last.type, nxMermaidBlockType);
    expect(editor.document.root.children.first.delta!.toPlainText(), 'Keep me');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
