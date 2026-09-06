import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'content_files.dart';

/// A small per-account index. Full payloads, including queued versions, are files.
/// Apps supply remote calls and projections; storage never interprets their data.
class FileLibrary {
  FileLibrary({required this.database, required this.files});

  factory FileLibrary.application(String account) => FileLibrary(
    database: LibraryDatabase(
      driftDatabase(
        name: 'nx_library_${sha256.convert(utf8.encode(account))}',
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      ),
    ),
    files: ContentFiles.application(account),
  );

  final LibraryDatabase database;
  final ContentFiles files;
  Future<void> _writes = Future.value();

  // Preserve invocation order, including slow file writes. A failed save must
  // not poison the queue for the next save.
  Future<T> _serialize<T>(Future<T> Function() work) {
    final result = _writes.then((_) => work());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// A catalog is a named, complete remote response. Publish its immutable
  /// references together, so an interrupted refresh cannot mix two responses.
  Future<void> replaceCatalog(
    String name,
    List<LibraryRecord> records,
  ) => _serialize(() async {
    final references = <String>[];
    for (final record in records) {
      references.add(
        await files.write(record.collection, record.id, record.content),
      );
    }
    await database.transaction(() async {
      await database.customStatement(
        'DELETE FROM catalog_items WHERE catalog=?',
        [name],
      );
      for (var i = 0; i < records.length; i++) {
        final record = records[i];
        await database.customStatement(
          'INSERT INTO catalog_items (catalog, position, item_id, body_ref, summary_json) VALUES (?, ?, ?, ?, ?)',
          [name, i, record.id, references[i], jsonEncode(record.summary)],
        );
      }
      await database.customStatement(
        'INSERT INTO catalog_checks (catalog, checked_at) VALUES (?, ?) '
        'ON CONFLICT(catalog) DO UPDATE SET checked_at=excluded.checked_at',
        [name, DateTime.now().toUtc().toIso8601String()],
      );
    });
  });

  Future<bool> hasCatalog(String name) async =>
      (await database
              .customSelect(
                'SELECT 1 FROM catalog_checks WHERE catalog=?',
                variables: [Variable(name)],
              )
              .get())
          .isNotEmpty;

  Future<List<CatalogItem>> catalog(
    String name, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 1000 || offset < 0) {
      throw ArgumentError('Invalid catalog page');
    }
    final rows = await database
        .customSelect(
          'SELECT * FROM catalog_items WHERE catalog=? ORDER BY position LIMIT ? OFFSET ?',
          variables: [Variable(name), Variable(limit), Variable(offset)],
        )
        .get();
    return [
      for (final row in rows)
        CatalogItem(
          row.read('item_id'),
          row.read('body_ref'),
          Map<String, Object?>.from(
            jsonDecode(row.read<String>('summary_json')) as Map,
          ),
        ),
    ];
  }

  Future<void> invalidateCatalogs() => _serialize(
    () => database.transaction(() async {
      await database.customStatement('DELETE FROM catalog_checks');
      await database.customStatement('DELETE FROM catalog_items');
    }),
  );

  Future<StoredItem?> metadata(String collection, String id) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM stored_items WHERE collection = ? AND item_id = ?',
          variables: [Variable(collection), Variable(id)],
        )
        .get();
    return rows.isEmpty ? null : StoredItem.fromRow(rows.single);
  }

  Future<String?> read(String collection, String id) async {
    final item = await metadata(collection, id);
    return item == null || item.deleted ? null : files.read(item.reference);
  }

  Future<List<StoredItem>> list(
    String collection, {
    int limit = 50,
    String? after,
  }) async {
    if (limit < 1 || limit > 1000) throw ArgumentError.value(limit, 'limit');
    final rows = await database
        .customSelect(
          'SELECT * FROM stored_items WHERE collection = ? AND deleted = 0 '
          'AND item_id > ? ORDER BY item_id LIMIT ?',
          variables: [
            Variable(collection),
            Variable(after ?? ''),
            Variable(limit),
          ],
        )
        .get();
    return rows.map(StoredItem.fromRow).toList();
  }

  /// Unacknowledged local content is never replaced by a remote refresh.
  Future<void> saveRemote(
    String collection,
    String id,
    String content, {
    Map<String, Object?> summary = const {},
    String? revision,
  }) => _serialize(() async {
    final before = await metadata(collection, id);
    if (before?.pending == true) return;
    final reference = await files.write(collection, id, content);
    await database.transaction(() async {
      final current = await metadata(collection, id);
      if (current?.pending == true) return;
      await database.customStatement(
        '''
        INSERT INTO stored_items (collection, item_id, body_ref, summary_json, revision, pending, deleted)
        VALUES (?, ?, ?, ?, ?, 0, 0)
        ON CONFLICT(collection, item_id) DO UPDATE SET body_ref=excluded.body_ref,
          summary_json=excluded.summary_json, revision=excluded.revision, deleted=0
      ''',
        [collection, id, reference, jsonEncode(summary), revision],
      );
    });
  });

  /// Every save advances a generation, including A → B → A edits. The file
  /// checksum identifies content, never the identity of a pending mutation.
  Future<StoredItem> saveLocal(
    String collection,
    String id,
    String content, {
    Map<String, Object?> summary = const {},
    bool deleted = false,
  }) => _serialize(() async {
    final reference = await files.write(collection, id, content);
    await database.customStatement(
      '''
      INSERT INTO stored_items (collection, item_id, body_ref, summary_json, pending, deleted)
      VALUES (?, ?, ?, ?, 1, ?)
      ON CONFLICT(collection, item_id) DO UPDATE SET body_ref=excluded.body_ref,
        summary_json=excluded.summary_json, pending=1, deleted=excluded.deleted,
        generation=stored_items.generation + 1
    ''',
      [collection, id, reference, jsonEncode(summary), deleted ? 1 : 0],
    );
    return (await metadata(collection, id))!;
  });

  Future<List<StoredItem>> pending({int limit = 50}) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM stored_items WHERE pending = 1 ORDER BY collection, item_id LIMIT ?',
          variables: [Variable(limit)],
        )
        .get();
    return rows.map(StoredItem.fromRow).toList();
  }

  Future<void> acknowledge(StoredItem uploaded, {String? revision}) async {
    await database.customStatement(
      '''
      UPDATE stored_items SET pending=0, revision=?
      WHERE collection=? AND item_id=? AND body_ref=? AND deleted=? AND generation=?
    ''',
      [
        revision,
        uploaded.collection,
        uploaded.id,
        uploaded.reference,
        uploaded.deleted ? 1 : 0,
        uploaded.generation,
      ],
    );
  }

  Future<void> removeRemote(String collection, String id) async {
    await database.customStatement(
      'DELETE FROM stored_items WHERE collection=? AND item_id=? AND pending=0',
      [collection, id],
    );
  }

  Future<void> close() async {
    await _writes;
    await database.close();
  }
}

class StoredItem {
  const StoredItem({
    required this.collection,
    required this.id,
    required this.reference,
    required this.summary,
    required this.pending,
    required this.deleted,
    this.revision,
    required this.generation,
  });
  final String collection;
  final String id;
  final String reference;
  final Map<String, Object?> summary;
  final bool pending;
  final bool deleted;
  final String? revision;
  final int generation;

  factory StoredItem.fromRow(QueryRow row) => StoredItem(
    collection: row.read('collection'),
    id: row.read('item_id'),
    reference: row.read('body_ref'),
    summary: Map<String, Object?>.from(
      jsonDecode(row.read<String>('summary_json')) as Map,
    ),
    pending: row.read<int>('pending') != 0,
    deleted: row.read<int>('deleted') != 0,
    revision: row.readNullable('revision'),
    generation: row.read('generation'),
  );
}

class LibraryRecord {
  const LibraryRecord({
    required this.collection,
    required this.id,
    required this.content,
    this.summary = const {},
  });
  final String collection;
  final String id;
  final String content;
  final Map<String, Object?> summary;
}

class CatalogItem {
  const CatalogItem(this.id, this.reference, this.summary);
  final String id;
  final String reference;
  final Map<String, Object?> summary;
}

class LibraryDatabase extends GeneratedDatabase {
  LibraryDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE catalog_checks (catalog TEXT PRIMARY KEY, checked_at TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE catalog_items (catalog TEXT NOT NULL, position INTEGER NOT NULL, '
        'item_id TEXT NOT NULL, body_ref TEXT NOT NULL, summary_json TEXT NOT NULL, PRIMARY KEY(catalog, position))',
      );
      await customStatement('''
      CREATE TABLE stored_items (
        collection TEXT NOT NULL, item_id TEXT NOT NULL, body_ref TEXT NOT NULL,
        summary_json TEXT NOT NULL, revision TEXT, pending INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0, generation INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (collection, item_id)
      )
    ''');
      await customStatement(
        'CREATE INDEX stored_pending ON stored_items(pending, collection, item_id)',
      );
    },
  );
}
