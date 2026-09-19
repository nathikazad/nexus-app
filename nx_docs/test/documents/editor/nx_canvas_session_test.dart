import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas_core/drawing.dart';
import 'package:nx_docs/documents/editor/nx_canvas_session.dart';
import 'package:nx_docs/sync/native/drift_local_notes_store.dart';
import 'package:nx_docs/sync/native/notes_database.dart';
import 'package:nx_docs/documents/document_models.dart';
import '../../support/offline_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nx_canvas/editor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final drawing = Drawing(
    boards: {'width': 900.0, 'height': 1100.0},
    strokes: [
      InkStroke(
        id: 'pen-1',
        points: [const Dot(10, 20, .4), const Dot(55, 80, .9)],
        color: 0xff000000,
        width: 3,
      ),
    ],
    view: const CanvasView(x: 20, y: -15, scale: 1.5),
    places: [
      const SavedPlace('Opening', CanvasView(x: 20, y: -15, scale: 1.5)),
    ],
  );
  EditorState editorWith(Node node) => EditorState(
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
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'local diagnostics contain timing metadata without drawing content',
    () async {
      final node = nxCanvasNode();
      final editor = editorWith(node);
      addTearDown(editor.dispose);
      final events = <Map<dynamic, dynamic>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'diagnostic') {
          events.add(call.arguments as Map);
        }
        if (call.method == 'available') return true;
        if (call.method == 'openDocument') {
          final args = call.arguments as Map;
          return {
            'documentId': args['documentId'],
            'drawing': drawing.toJson(),
            'saveToken': 'one',
          };
        }
        if (call.method == 'ackDocument') return true;
        return null;
      });
      await NxCanvasSession(
        editor: editor,
        documentId: 'private-document',
        persist: () async {},
      ).open(node);
      await Future<void>.delayed(Duration.zero);
      for (final stage in ['docs.persist', 'docs.apply_drawing']) {
        expect(
          events.any((e) => e['stage'] == stage && e['phase'] == 'begin'),
          isTrue,
        );
        expect(
          events.any(
            (e) =>
                e['stage'] == stage &&
                e['phase'] == 'end' &&
                (e['duration_us'] as int) >= 0,
          ),
          isTrue,
        );
      }
      expect(
        events.every(
          (e) => e.keys.every(
            ['stage', 'phase', 'dart_time_ms', 'duration_us'].contains,
          ),
        ),
        isTrue,
      );
      expect(jsonEncode(events), isNot(contains('private-document')));
      expect(jsonEncode(events), isNot(contains('pen-1')));
    },
  );

  test(
    'native result survives real database restart inside document JSON',
    () async {
      final directory = await Directory.systemTemp.createTemp('nx-canvas-doc-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/notes.sqlite');
      var database = NotesDatabase(NativeDatabase(file));
      var store = DriftLocalNotesStore(
        database: database,
        accountKey: 'prod:user-1',
      );
      final node = nxCanvasNode();
      final editor = editorWith(node);
      addTearDown(editor.dispose);
      Map<String, dynamic>? pending;
      var acknowledged = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'available':
            return true;
          case 'recoverDocument':
            return pending;
          case 'openDocument':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            pending = {
              'documentId': args['documentId'],
              'drawing': drawing.toJson(),
              'saveToken': 'saved-1',
            };
            return pending;
          case 'ackDocument':
            final stored = await store.getDocument(
              const DocumentKey(localId: 'local-1'),
            );
            final restored = Document.fromJson(
              Map<String, dynamic>.from(stored!.document.jsonDocument),
            );
            expect(
              canvasDrawing(restored.root.children[1]).toJson(),
              drawing.toJson(),
            );
            acknowledged = true;
            pending = null;
            return true;
        }
        return null;
      });
      final session = NxCanvasSession(
        editor: editor,
        documentId: '1',
        persist: () async {
          final local = offlineLocalDocument();
          await store.saveDraftAndEnqueue(
            local.copyWith(
              document: local.document.copyWith(
                jsonDocument: {
                  'format': 'appflowy_document',
                  ...editor.document.toJson(),
                },
              ),
            ),
            operation: offlinePendingOperation(),
          );
        },
      );
      await session.open(node);
      expect(acknowledged, isTrue);
      expect(pending, isNull);
      await database.close();
      database = NotesDatabase(NativeDatabase(file));
      addTearDown(database.close);
      store = DriftLocalNotesStore(
        database: database,
        accountKey: 'prod:user-1',
      );
      final stored = await store.getDocument(
        const DocumentKey(localId: 'local-1'),
      );
      final restored = Document.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(stored!.document.jsonDocument)),
        ),
      );
      expect(restored.root.children.first.delta!.toPlainText(), 'Before');
      expect(restored.root.children.last.delta!.toPlainText(), 'After');
      expect(
        canvasDrawing(restored.root.children[1]).toJson(),
        drawing.toJson(),
      );
    },
  );

  testWidgets(
    'live canvas leaves Docs untouched and reconciles only after native return',
    (tester) async {
      final node = nxCanvasNode();
      final editor = editorWith(node);
      addTearDown(editor.dispose);
      final initialDrawing = canvasDrawing(node).toJson();
      final opened = Completer<Map<String, dynamic>>();
      Map<String, dynamic>? pending;
      var acknowledgments = 0;
      var saves = 0;
      var peeks = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'available':
            return true;
          case 'recoverDocument':
            return null;
          case 'openDocument':
            pending = {
              'documentId': (call.arguments as Map)['documentId'],
              'drawing': drawing.toJson(),
              'saveToken': 'final-1',
            };
            return opened.future;
          case 'peekDocument':
            peeks++;
            return pending;
          case 'ackDocument':
            expectSync(saves, 2);
            acknowledgments++;
            return true;
        }
        return null;
      });
      final session = NxCanvasSession(
        editor: editor,
        documentId: 'doc-live',
        persist: () async {
          saves++;
        },
      );
      final opening = session.open(node);
      await tester.pump();
      expect(pending, isNotNull);
      // Several former autosave intervals must not transfer or apply any drawing.
      await tester.pump(const Duration(seconds: 20));
      expect(saves, 1);
      expect(peeks, 0);
      expect(acknowledgments, 0);
      expect(canvasDrawing(node).toJson(), initialDrawing);
      opened.complete(pending!);
      await tester.pump();
      await opening;
      await tester.pump(const Duration(milliseconds: 100));
      expect(canvasDrawing(node).toJson(), drawing.toJson());
      expect(acknowledgments, 1);
      expect(saves, 2);
    },
  );

  test('failed save keeps journal and later recovery is idempotent', () async {
    final node = nxCanvasNode();
    final editor = editorWith(node);
    addTearDown(editor.dispose);
    var fail = true;
    var ack = 0;
    final session = NxCanvasSession(
      editor: editor,
      documentId: 'doc-a',
      persist: () async {
        if (fail) throw StateError('disk failure');
      },
    );
    Map<String, dynamic>? pending = {
      'documentId': session.identity(node),
      'drawing': drawing.toJson(),
      'saveToken': 'recover-1',
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'recoverDocument') return pending;
      if (call.method == 'ackDocument') {
        ack++;
        pending = null;
        return true;
      }
      return null;
    });
    await expectLater(session.recover(node), throwsStateError);
    expect(pending, isNotNull);
    expect(ack, 0);
    fail = false;
    expect(await session.recover(node), isTrue);
    expect(await session.recover(node), isFalse);
    expect(canvasDrawing(node).strokes, hasLength(1));
    expect(ack, 1);
  });

  test('recovery never applies another document canvas to this node', () async {
    final node = nxCanvasNode();
    final editor = editorWith(node);
    addTearDown(editor.dispose);
    var writes = 0;
    var ack = 0;
    final session = NxCanvasSession(
      editor: editor,
      documentId: 'doc-b',
      persist: () async {
        writes++;
      },
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'recoverDocument') {
        return {
          'documentId': jsonEncode(['doc-a', node.attributes['canvas_id']]),
          'drawing': drawing.toJson(),
          'saveToken': 'other',
        };
      }
      if (call.method == 'ackDocument') {
        ack++;
        return true;
      }
      return null;
    });
    expect(await session.recover(node), isFalse);
    expect(writes, 0);
    expect(ack, 0);
    expect(canvasDrawing(node).strokes, isEmpty);
  });
}
