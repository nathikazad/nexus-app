import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../canvas/drawing.dart';

class CanvasStore {
  CanvasStore(this.database);
  final Database database;
  static Future<CanvasStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final location =
        path ?? p.join(await dbFactory.getDatabasesPath(), 'nx_canvas.sqlite');
    return CanvasStore(
      await dbFactory.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 2,
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await db.execute(
                "ALTER TABLE canvases ADD COLUMN title TEXT NOT NULL DEFAULT 'Untitled drawing'",
              );
              await db.update(
                'canvases',
                {'title': 'First canvas'},
                where: 'id = ?',
                whereArgs: ['prototype'],
              );
            }
          },
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE canvases (id TEXT PRIMARY KEY, drawing_json TEXT NOT NULL, '
              "preview_png BLOB, updated_at TEXT NOT NULL, title TEXT NOT NULL DEFAULT 'Untitled drawing')",
            );
          },
        ),
      ),
    );
  }

  Future<Drawing> load() async {
    final rows = await database.query(
      'canvases',
      where: 'id = ?',
      whereArgs: ['prototype'],
    );
    if (rows.isEmpty) return Drawing();
    return Drawing.fromJson(
      jsonDecode(rows.single['drawing_json'] as String) as Map<String, dynamic>,
    );
  }

  Future<void> save(Drawing drawing, Uint8List preview) async {
    await database.transaction((tx) async {
      await tx.insert('canvases', {
        'id': 'prototype',
        'drawing_json': jsonEncode(drawing.toJson()),
        'preview_png': preview,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> close() => database.close();
}

class CanvasTileData {
  const CanvasTileData(this.id, this.title, this.preview, this.updatedAt);
  final String id, title;
  final Uint8List? preview;
  final DateTime updatedAt;
}

extension CanvasGalleryStore on CanvasStore {
  Future<List<CanvasTileData>> listCanvases() async {
    final rows = await database.query(
      'canvases',
      columns: ['id', 'title', 'preview_png', 'updated_at'],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map(
          (row) => CanvasTileData(
            row['id'] as String,
            row['title'] as String,
            row['preview_png'] as Uint8List?,
            DateTime.parse(row['updated_at'] as String),
          ),
        )
        .toList();
  }

  Future<Drawing> loadCanvas(String id) async {
    final rows = await database.query(
      'canvases',
      columns: ['drawing_json'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Drawing not found');
    return Drawing.fromJson(jsonDecode(rows.single['drawing_json'] as String));
  }

  Future<void> saveCanvas(
    String id,
    String title,
    Drawing drawing,
    Uint8List preview,
  ) async {
    await database.transaction((tx) async {
      await tx.insert('canvases', {
        'id': id,
        'title': title,
        'drawing_json': jsonEncode(drawing.toJson()),
        'preview_png': preview,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> renameCanvas(String id, String title) async {
    await database.update(
      'canvases',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  CanvasStore forCanvas(String id, String title) =>
      _ScopedCanvasStore(database, id, title);
}

class _ScopedCanvasStore extends CanvasStore {
  _ScopedCanvasStore(super.database, this.id, this.title);
  final String id, title;
  @override
  Future<Drawing> load() => loadCanvas(id);
  @override
  Future<void> save(Drawing drawing, Uint8List preview) =>
      saveCanvas(id, title, drawing, preview);
}
