import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nx_canvas/storage/canvas_store.dart';
import 'package:nx_canvas/storage/native_canvas_handoff.dart';
import 'package:nx_canvas/canvas/drawing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native recovery replaces only its drawing, persists preview, then acknowledges',
    () async {
      sqfliteFfiInit();
      final store = await CanvasStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final first = Drawing(
        strokes: [
          InkStroke(
            id: 'first',
            points: const [Dot(10, 20), Dot(30, 40)],
            color: 0xff000000,
            width: 3,
          ),
        ],
      );
      await store.saveCanvas('a', 'First', first, Uint8List(0));
      await store.saveCanvas('b', 'Second', first, Uint8List(0));
      // Full-document return can represent erasing all ink; it is not an append.
      final edited = Drawing(view: const CanvasView(x: -200, scale: .5));
      final snapshot = {
        'documentId': 'b',
        'title': 'Second',
        'drawing': edited.toJson(),
        'saveToken': 'save-1',
      };
      const channel = MethodChannel('nx_canvas/editor');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var acknowledged = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'recover') return [];
        if (call.method == 'recoverDocument') return snapshot;
        if (call.method == 'ackDocument') {
          expect(call.arguments, 'save-1');
          expect((await store.loadCanvas('a')).toJson(), first.toJson());
          expect((await store.loadCanvas('b')).toJson(), edited.toJson());
          expect(
            (await store.listCanvases())
                .firstWhere((t) => t.id == 'b')
                .preview!
                .length,
            greaterThan(0),
          );
          acknowledged = true;
          return true;
        }
        fail('Unexpected call ${call.method}');
      });
      final handoff = NativeCanvasHandoff(store);
      await handoff.recover();
      expect(acknowledged, isTrue);
      // A retry after interrupted acknowledgement must not duplicate drawings.
      await handoff.recover();
      expect(await store.listCanvases(), hasLength(2));
      messenger.setMockMethodCallHandler(channel, null);
      await store.close();
    },
  );
}
