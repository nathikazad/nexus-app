import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/data/offline/reading_history_store.dart';
import 'package:nx_books/data/offline/reading_position_store.dart';
import 'package:nx_books/domain/book/reading_history.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const id = DocumentIdentity(id: 7, modelType: 'Document');
  test(
    'reading anchors survive reopening and are scoped by account and type',
    () async {
      SharedPreferences.setMockInitialValues({});
      await const ReadingPositionStore(
        'a',
      ).save(id, const ReadingPosition(index: 25, alignment: -0.12));
      final position = await const ReadingPositionStore('a').load(id);
      expect(position?.index, 25);
      expect(position?.alignment, -0.12);
      expect(await const ReadingPositionStore('b').load(id), isNull);
      expect(
        await const ReadingPositionStore(
          'a',
        ).load(const DocumentIdentity(id: 7, modelType: 'Book')),
        isNull,
      );
    },
  );

  test(
    'history survives restart and stale downloads cannot discard new replies',
    () async {
      final dir = await Directory.systemTemp.createTemp('nx-history-test-');
      final library = FileLibrary(
        database: LibraryDatabase(NativeDatabase.memory()),
        files: DirectoryContentFiles(dir),
      );
      addTearDown(() async {
        await library.close();
        await dir.delete(recursive: true);
      });
      final store = ReadingHistoryStore(library);
      const old = ReadingHistory('Chapter', [
        ReadingMessage('user', 'Question'),
      ]);
      const next = ReadingHistory('Chapter', [
        ReadingMessage('user', 'Question'),
        ReadingMessage('assistant', 'Answer'),
      ]);
      await store.save(id, old);
      final token = store.generation;
      await store.save(id, next);
      await store.saveDownloaded(id, old, token);
      final reopened = ReadingHistoryStore(library);
      expect((await reopened.load(id))?.messages.last.text, 'Answer');
      await reopened.saveDownloaded(id, old, reopened.generation);
      expect((await reopened.load(id))?.messages.length, 2);
      expect(
        await reopened.load(const DocumentIdentity(id: 7, modelType: 'Book')),
        isNull,
      );
      await reopened.save(id, const ReadingHistory('Chapter', []));
      expect((await ReadingHistoryStore(library).load(id))?.messages, isEmpty);
    },
  );
}
