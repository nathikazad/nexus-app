import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_books/data/offline/book_file_cache.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temporary;
  late BinaryContentFiles files;
  late int requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('nx-book-cache-');
    files = DirectoryBinaryContentFiles('${temporary.path}/content');
    requests = 0;
  });

  tearDown(() => temporary.delete(recursive: true));

  BookFileCache cache() => BookFileCache(
    accountKey: 'test-account',
    origin: Uri.parse('https://nexus.kgql.io'),
    files: files,
    client: MockClient((request) async {
      requests++;
      expect(request.url.host, 'nexus.kgql.io');
      return http.Response.bytes([37, 80, 68, 70, 45, requests], 200);
    }),
  );

  test('downloads once and opens the verified local copy offline', () async {
    final bookCache = cache();
    final firstPath = await bookCache.openPath(_book('/books/9-example.pdf'));
    expect(requests, 1);
    expect(await File(firstPath).readAsBytes(), [37, 80, 68, 70, 45, 1]);

    final secondPath = await bookCache.openPath(_book('/books/9-example.pdf'));
    expect(secondPath, firstPath);
    expect(requests, 1);
  });

  test('corrupt local content is downloaded and verified again', () async {
    final bookCache = cache();
    final path = await bookCache.openPath(_book('/books/9-example.pdf'));
    await File(path).writeAsBytes([0]);
    final repairedPath = await bookCache.openPath(
      _book('/books/9-example.pdf'),
    );
    expect(requests, 2);
    expect(await File(repairedPath).readAsBytes(), [37, 80, 68, 70, 45, 2]);
  });

  test('rejects links outside the configured Nexus origin', () async {
    await expectLater(
      cache().openPath(_book('https://example.com/books/stolen.pdf')),
      throwsFormatException,
    );
    expect(requests, 0);
  });

  test(
    'checks server checksum and size before acknowledging a download',
    () async {
      const hash =
          '4b9d984d2b0cc5ef4d53caf2ef449f2bfd0cbf6a68d2e6b24c52f98e0d9e7b91';
      final book = _book('/books/9-example.pdf', hash: hash, size: 6);
      final bookCache = cache();
      await bookCache.openPath(book);
      await bookCache.openPath(book);
      expect(requests, 1);
      await expectLater(
        bookCache.openPath(
          _book('/books/9-example.pdf', hash: 'incorrect', size: 6),
        ),
        throwsStateError,
      );
      expect(requests, 2);
      // The bad download must not replace the acknowledged metadata.
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('nx_books.offline.test-account.book_file.9'),
        contains(hash),
      );
    },
  );
}

NxBook _book(String bookLink, {String? hash, int? size}) => NxBook(
  id: 9,
  title: 'Example',
  description: '',
  author: '',
  link: '',
  bookLink: bookLink,
  bookFileHash: hash,
  bookFileSize: size,
  tags: const [],
  readingState: BookReadingState.reading,
  rank: 0,
  totalChapters: null,
  currentChapter: null,
  wordCount: 0,
  updatedAt: DateTime.utc(2026),
  updatedLabel: '',
);
