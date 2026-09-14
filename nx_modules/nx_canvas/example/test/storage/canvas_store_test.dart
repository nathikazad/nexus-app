import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nx_canvas/storage/canvas_store.dart';
import 'package:nx_canvas/canvas/drawing.dart';

void main() {
  test(
    'SQLite reopens editable fragments and matching preview atomically',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('nx-canvas-test-');
      final path = '${dir.path}/test.sqlite';
      var store = await CanvasStore.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final line = InkStroke(
        id: 'a',
        points: const [Dot(-100, 20, .4), Dot(100, 20, .8)],
        color: 42,
        width: 2,
      );
      final drawing = Drawing(
        strokes: eraseDisk(line, const Dot(0, 20), 10),
        view: const CanvasView(x: 120, y: -300, scale: .5),
      );
      await store.save(drawing, Uint8List.fromList([1, 2, 3]));
      await store.close();
      store = await CanvasStore.open(factory: databaseFactoryFfi, path: path);
      expect((await store.load()).toJson(), drawing.toJson());
      final rows = await store.database.query('canvases');
      expect(rows.single['preview_png'], [1, 2, 3]);
      await store.close();
      await dir.delete(recursive: true);
    },
  );
}
