import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';

void main() {
  late Directory directory;
  late DirectoryContentFiles files;
  late FileLibrary library;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nx-file-library-');
    files = DirectoryContentFiles(Directory('${directory.path}/content'));
    library = FileLibrary(
      database: LibraryDatabase(
        NativeDatabase(File('${directory.path}/index.sqlite')),
      ),
      files: files,
    );
  });

  tearDown(() async {
    await library.close();
    await directory.delete(recursive: true);
  });

  for (final collection in ['books', 'documents', 'expenses', 'cards']) {
    test(
      '$collection: restart, metadata-only listing and immutable upload version',
      () async {
        final original = await library.saveLocal(
          collection,
          'one',
          'large body 🎉',
          summary: {'title': 'One'},
        );
        expect(files.reads, 0);
        expect((await library.list(collection)).single.summary['title'], 'One');
        expect(files.reads, 0);
        await library.close();
        library = FileLibrary(
          database: LibraryDatabase(
            NativeDatabase(File('${directory.path}/index.sqlite')),
          ),
          files: files,
        );
        expect(await library.read(collection, 'one'), 'large body 🎉');
        await library.saveLocal(collection, 'one', 'new body');
        expect(await files.read(original.reference), 'large body 🎉');
        await library.acknowledge(original, revision: 'old-server-version');
        expect((await library.metadata(collection, 'one'))!.pending, isTrue);
      },
    );
  }

  test('A → B → A uses distinct generations, not just checksums', () async {
    final first = await library.saveLocal('documents', '1', 'A');
    await library.saveLocal('documents', '1', 'B');
    final last = await library.saveLocal('documents', '1', 'A');
    expect(last.reference, first.reference);
    expect(last.generation, greaterThan(first.generation));
    await library.acknowledge(first);
    expect((await library.pending()).single.generation, last.generation);
    await library.acknowledge(last, revision: 'r3');
    expect(await library.pending(), isEmpty);
  });

  test(
    'failed SQLite publication leaves the old file and pending generation intact',
    () async {
      final first = await library.saveLocal('documents', '1', 'old');
      await library.database.customStatement(
        "CREATE TRIGGER reject_publish BEFORE UPDATE ON stored_items BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      await expectLater(
        library.saveLocal('documents', '1', 'new'),
        throwsA(anything),
      );
      expect(await library.read('documents', '1'), 'old');
      expect((await library.pending()).single.generation, first.generation);
      await library.database.customStatement('DROP TRIGGER reject_publish');
      await library.saveLocal('documents', '1', 'retry');
      expect(await library.read('documents', '1'), 'retry');
    },
  );

  test(
    'catalog replacement is atomic even after its old rows were deleted inside the transaction',
    () async {
      await library.replaceCatalog('books', [
        const LibraryRecord(
          collection: 'books',
          id: '1',
          content: 'old',
          summary: {'title': 'Old'},
        ),
      ]);
      final first = (await library.catalog('books')).single;
      expect(files.reads, 0);
      await library.database.customStatement(
        "CREATE TRIGGER reject_catalog BEFORE INSERT ON catalog_items BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      await expectLater(
        library.replaceCatalog('books', [
          const LibraryRecord(collection: 'books', id: '2', content: 'new'),
        ]),
        throwsA(anything),
      );
      expect(
        (await library.catalog('books')).single.reference,
        first.reference,
      );
      expect(await library.hasCatalog('books'), isTrue);
      expect(await files.read(first.reference), 'old');
    },
  );

  test(
    'a missing file is distinguishable from an item that was never downloaded',
    () async {
      final item = await library.saveLocal('documents', '1', 'body');
      final reference = ContentReference.decode(item.reference);
      await File('${files.directory.path}/${reference.path}').delete();
      await expectLater(
        library.read('documents', '1'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await library.read('documents', 'unknown'), isNull);
      expect((await library.pending()).single.id, '1');
    },
  );

  test('remote refresh and remote delete preserve pending edits', () async {
    await library.saveLocal('documents', '1', 'local');
    await library.saveRemote('documents', '1', 'remote');
    await library.removeRemote('documents', '1');
    expect(await library.read('documents', '1'), 'local');
    expect(files.writes, 1);
  });

  test(
    'deletion is durable pending metadata, not loss of upload content',
    () async {
      final deleted = await library.saveLocal(
        'cards',
        '1',
        'last body',
        deleted: true,
      );
      expect(await library.read('cards', '1'), isNull);
      expect(await library.list('cards'), isEmpty);
      expect((await library.pending()).single.deleted, isTrue);
      expect(await files.read(deleted.reference), 'last body');
    },
  );

  test('concurrent saves publish in invocation order', () async {
    await Future.wait([
      library.saveLocal('documents', '1', 'A' * 200000),
      library.saveLocal('documents', '1', 'B'),
    ]);
    expect(await library.read('documents', '1'), 'B');
  });

  test(
    'corruption is reported; it is never returned as an empty document',
    () async {
      final item = await library.saveLocal('documents', '1', 'hello');
      final reference = ContentReference.decode(item.reference);
      await File(
        '${files.directory.path}/${reference.path}',
      ).writeAsString('xxxxx');
      await expectLater(library.read('documents', '1'), throwsFormatException);
      await expectLater(
        library.saveLocal('documents', '1', 'hello'),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await library.metadata('documents', '1'))!.generation,
        item.generation,
      );
      await library.saveLocal('documents', '1', 'recovered');
      expect(await library.read('documents', '1'), 'recovered');
    },
  );

  test(
    'unsafe references and symlinks cannot escape the account directory',
    () async {
      await expectLater(
        files.read(ContentReference('../other/secret', '0' * 64, 0).encode()),
        throwsFormatException,
      );
      await files.directory.create(recursive: true);
      final outside = await Directory('${directory.path}/outside').create();
      await Link('${files.directory.path}/documents').create(outside.path);
      await expectLater(
        files.write('documents', '1', 'body'),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    '1000-item index pages require zero body reads and one edit writes one file',
    () async {
      for (var i = 0; i < 1000; i++) {
        await library.saveRemote(
          'documents',
          i.toString().padLeft(4, '0'),
          'body-$i',
          summary: {'title': 'Document $i'},
        );
      }
      final page = await library.list('documents', limit: 50);
      final next = await library.list(
        'documents',
        limit: 50,
        after: page.last.id,
      );
      expect(page.length, 50);
      expect(next.first.id, '0050');
      expect(files.reads, 0);
      final writes = files.writes;
      await library.saveLocal('documents', '0001', 'changed');
      expect(files.writes - writes, 1);
      expect(files.reads, 0);
    },
  );
}
