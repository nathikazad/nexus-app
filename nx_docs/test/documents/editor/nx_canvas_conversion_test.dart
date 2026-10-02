import 'dart:async';
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_canvas_core/drawing.dart';
import 'package:nx_docs/documents/editor/canvas_conversion_service.dart';
import 'package:nx_docs/documents/editor/nx_appflowy_blocks.dart';
import 'package:nx_docs/documents/editor/nx_canvas_conversion_session.dart';

CanvasTextProposal proposal() => const CanvasTextProposal(
  blocks: [
    {
      'type': 'paragraph',
      'data': {
        'delta': [
          {'insert': 'Converted script'},
        ],
      },
    },
  ],
  warnings: ['Name is unclear.'],
);
Node canvas() => nxCanvasNode()
  ..updateAttributes({
    'drawing': Drawing(
      strokes: [
        InkStroke(
          id: 'one',
          points: [const Dot(-20, 20), const Dot(40, 80)],
          color: 0xff000000,
          width: 3,
        ),
      ],
    ).toJson(),
  });
EditorState editorFor(Node node) => EditorState(
  document: Document(
    root: Node(
      type: 'page',
      children: [
        paragraphNode(text: 'Before'),
        node,
        paragraphNode(text: 'After'),
      ],
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nx_canvas/editor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => messenger.setMockMethodCallHandler(channel, (call) async => null),
  );
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'inserts below the exact canvas, preserves neighbors, and deduplicates retries',
    () async {
      final node = canvas();
      final editor = editorFor(node);
      addTearDown(editor.dispose);
      final before = jsonEncode(node.attributes['drawing']);
      var calls = 0;
      var saves = 0;
      final session = NxCanvasConversionSession(
        editor: editor,
        persist: () async {
          saves++;
        },
        isActive: () => true,
        convert: (id, drawing) async {
          expect(id, node.attributes['canvas_id']);
          expect(saves, 1);
          expect(jsonEncode(drawing), before);
          calls++;
          return proposal();
        },
      );
      await session.run(node);
      expect(
        editor.document.root.children
            .map((n) => n.delta?.toPlainText())
            .toList(),
        ['Before', null, 'Converted script', 'After'],
      );
      expect(jsonEncode(node.attributes['drawing']), before);
      expect(session.warnings, ['Name is unclear.']);
      await session.run(node);
      expect(calls, 1);
      expect(saves, 2);
    },
  );

  for (final change in [
    'drawing',
    'deleted',
    'account',
    'readonly',
    'duplicate',
  ]) {
    test('rejects result after $change changes during the request', () async {
      final node = canvas();
      final editor = editorFor(node);
      addTearDown(editor.dispose);
      var active = true;
      final session = NxCanvasConversionSession(
        editor: editor,
        persist: () async {},
        isActive: () => active,
        convert: (id, drawing) async {
          if (change == 'drawing')
            node.updateAttributes({'drawing': Drawing().toJson()});
          if (change == 'account') active = false;
          if (change == 'readonly') editor.editable = false;
          if (change == 'deleted')
            await editor.apply(
              editor.transaction..deleteNode(node),
              options: const ApplyOptions(inMemoryUpdate: true),
            );
          if (change == 'duplicate')
            await editor.apply(
              editor.transaction..insertNode([3], Node.fromJson(node.toJson())),
              options: const ApplyOptions(inMemoryUpdate: true),
            );
          return proposal();
        },
      );
      await expectLater(session.run(node), throwsStateError);
      expect(
        editor.document.root.children.any(
          (n) => n.delta?.toPlainText() == 'Converted script',
        ),
        false,
      );
    });
  }

  test(
    'failed final save retries persistence without another agent call',
    () async {
      final node = canvas();
      final editor = editorFor(node);
      addTearDown(editor.dispose);
      var saves = 0;
      var calls = 0;
      final session = NxCanvasConversionSession(
        editor: editor,
        isActive: () => true,
        persist: () async {
          saves++;
          if (saves == 2) throw StateError('disk unavailable');
        },
        convert: (id, drawing) async {
          calls++;
          return proposal();
        },
      );
      await expectLater(session.run(node), throwsStateError);
      expect(session.pendingSave, true);
      await session.run(node);
      expect(session.pendingSave, false);
      expect(calls, 1);
      expect(saves, 3);
      expect(editor.document.root.children.length, 4);
    },
  );

  test(
    'fingerprint survives JSON key order and integral number normalization',
    () {
      expect(
        canvasConversionFingerprint({'x': 1.0, 'y': 2}),
        canvasConversionFingerprint({'y': 2.0, 'x': 1}),
      );
    },
  );

  test(
    'HTTP sends document/canvas identities and exact drawing to NX Docs agent route',
    () async {
      final node = canvas();
      final service = CanvasConversionService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/nx_docs/canvas/convert');
          final body = jsonDecode(request.body) as Map;
          expect(body['document_id'], 42);
          expect(body['canvas_id'], 'selected');
          expect(body['expected_drawing'], node.attributes['drawing']);
          return http.Response(
            jsonEncode({
              ...body,
              'blocks': proposal().blocks,
              'warnings': proposal().warnings,
            }),
            200,
          );
        }),
      );
      expect(
        (await service.convert(
          documentId: 42,
          canvasId: 'selected',
          drawing: Map<String, dynamic>.from(node.attributes['drawing'] as Map),
        )).blocks,
        proposal().blocks,
      );
    },
  );

  test('account switch discards completed HTTP response', () async {
    late CanvasConversionService service;
    service = CanvasConversionService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        service.dispose();
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      service.convert(documentId: 42, canvasId: 'selected', drawing: {}),
      throwsStateError,
    );
  });

  test('wrong canvas response is never applied', () async {
    final service = CanvasConversionService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        return http.Response(
          jsonEncode({
            ...body,
            'canvas_id': 'wrong',
            'blocks': proposal().blocks,
            'warnings': [],
          }),
          200,
        );
      }),
    );
    await expectLater(
      service.convert(documentId: 42, canvasId: 'selected', drawing: {}),
      throwsStateError,
    );
  });

  testWidgets('button dispatches once while busy and inserts returned text', (
    tester,
  ) async {
    final node = canvas();
    final editor = editorFor(node);
    addTearDown(editor.dispose);
    final result = Completer<CanvasTextProposal>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFlowyEditor(
            editorState: editor,
            blockComponentBuilders: nxBlockComponentBuilders(
              canvasDocumentId: '42',
              persistCanvasDocument: () async {},
              convertCanvas: (id, drawing) {
                calls++;
                return result.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Convert to text'), findsOneWidget);
    await tester.tap(find.text('Convert to text'));
    await tester.pump();
    expect(
      find.text('Converting…'),
      findsOneWidget,
      reason:
          'calls=$calls; texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
    );
    expect(calls, 1);
    result.complete(proposal());
    await tester.pumpAndSettle();
    expect(
      editor.document.root.children[2].delta?.toPlainText(),
      'Converted script',
    );
    expect(find.text('Name is unclear.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('read-only canvas has no convert button', (tester) async {
    final node = canvas();
    final editor = editorFor(node);
    editor.editable = false;
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFlowyEditor(
            editable: false,
            editorState: editor,
            blockComponentBuilders: nxBlockComponentBuilders(
              canvasDocumentId: '42',
              persistCanvasDocument: () async {},
              convertCanvas: (id, drawing) async => proposal(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Convert to text'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
