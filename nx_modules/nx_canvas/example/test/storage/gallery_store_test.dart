import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nx_canvas/storage/canvas_store.dart';
import 'package:nx_canvas/canvas/drawing.dart';

void main() {
  test(
    'gallery migrates old drawing and keeps multiple drawings isolated on reopen',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('nx-gallery-');
      final path = '${dir.path}/gallery.sqlite';
      final original = Drawing(
        strokes: [
          InkStroke(
            id: 'old',
            points: const [Dot(1, 2), Dot(30, 40)],
            color: 0xff000000,
            width: 3,
          ),
        ],
      );
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE canvases (id TEXT PRIMARY KEY, drawing_json TEXT NOT NULL, preview_png BLOB, updated_at TEXT NOT NULL)',
            );
            await db.insert('canvases', {
              'id': 'prototype',
              'drawing_json': jsonEncode(original.toJson()),
              'preview_png': Uint8List.fromList([1, 2]),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            });
          },
        ),
      );
      await old.close();
      var store = await CanvasStore.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      expect((await store.listCanvases()).single.title, 'First canvas');
      expect((await store.loadCanvas('prototype')).toJson(), original.toJson());
      final other = Drawing(view: const CanvasView(x: 200, scale: .5));
      await store.saveCanvas(
        'second',
        'Speech',
        other,
        Uint8List.fromList([3, 4]),
      );
      await store.renameCanvas('prototype', 'Original sketch');
      await store.close();
      store = await CanvasStore.open(factory: databaseFactoryFfi, path: path);
      expect(await store.listCanvases(), hasLength(2));
      expect((await store.loadCanvas('prototype')).toJson(), original.toJson());
      expect((await store.loadCanvas('second')).toJson(), other.toJson());
      final rows = await store.listCanvases();
      expect(rows.firstWhere((t) => t.id == 'second').preview, [3, 4]);
      expect(
        rows.firstWhere((t) => t.id == 'prototype').title,
        'Original sketch',
      );
      await store.close();
      await dir.delete(recursive: true);
    },
  );
}
