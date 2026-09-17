import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_expense/data/sync/expense_assets.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';

void main() {
  late Directory directory;
  late FileLibrary library;
  late DirectoryBinaryContentFiles files;
  late ExpenseAssets assets;
  var requests = 0;
  var offline = false;
  var content = <int>[];
  FileLibrary open() => FileLibrary(
    database: LibraryDatabase(NativeDatabase(File('${directory.path}/db'))),
    files: DirectoryContentFiles(Directory('${directory.path}/json')),
  );
  ExpenseAssets create({bool web = false}) => ExpenseAssets(
    library: web ? null : library,
    files: web ? null : files,
    origin: Uri.parse('https://nexus.example'),
    client: MockClient((request) async {
      requests++;
      expect(request.url.origin, 'https://nexus.example');
      expect(request.url.path, '/images/file');
      expect(request.followRedirects, false);
      if (offline) throw const SocketException('offline');
      return http.Response.bytes(content, 200);
    }),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('expense-assets-');
    library = open();
    files = DirectoryBinaryContentFiles('${directory.path}/binary');
    content = utf8.encode('%PDF-1.4 receipt version one');
    requests = 0;
    offline = false;
    assets = create();
  });
  tearDown(() async {
    await assets.close();
    await library.close();
    await directory.delete(recursive: true);
  });
  test(
    'downloaded PDF survives restart and opens offline without a request',
    () async {
      final hash = sha256.convert(content).toString();
      expect(await assets.read('bill.pdf', hash: hash), content);
      await assets.close();
      await library.close();
      library = open();
      assets = create();
      offline = true;
      expect(await assets.read('bill.pdf', hash: hash), content);
      expect(requests, 1);
    },
  );
  test(
    'changed hash downloads a new version even with the same filename',
    () async {
      final old = sha256.convert(content).toString();
      await assets.read('bill.pdf', hash: old);
      content = utf8.encode('%PDF-1.4 complete replacement');
      final updated = sha256.convert(content).toString();
      expect(await assets.read('bill.pdf', hash: updated), content);
      expect(requests, 2);
      expect(await assets.read('bill.pdf', hash: updated), content);
      expect(requests, 2);
    },
  );
  test(
    'corrupt cached file is repaired and bad server bytes are rejected',
    () async {
      final hash = sha256.convert(content).toString();
      await assets.read('bill.pdf', hash: hash);
      final reference = BinaryContentReference.decode(
        (await library.read('receipt_files', 'bill.pdf:$hash'))!,
      );
      final path = await files.localPath(reference);
      await File(path).writeAsString('damaged');
      expect(await assets.read('bill.pdf', hash: hash), content);
      expect(requests, 2);
      await expectLater(
        assets.read('other.pdf', hash: '0' * 64),
        throwsStateError,
      );
      expect(
        await library.read('receipt_files', 'other.pdf:${'0' * 64}'),
        isNull,
      );
    },
  );
  test(
    'browser files are not persisted, and unsafe paths are rejected',
    () async {
      await assets.close();
      assets = create(web: true);
      final hash = sha256.convert(content).toString();
      await assets.read('bill.pdf', hash: hash);
      expect(await library.read('receipt_files', 'bill.pdf:$hash'), isNull);
      offline = true;
      await expectLater(
        assets.read('bill.pdf', hash: hash),
        throwsA(isA<SocketException>()),
      );
      await expectLater(assets.read('../bill.pdf'), throwsFormatException);
      expect(requests, 2);
    },
  );
  test('background fill covers linked and unlinked images and PDFs', () async {
    final hash = sha256.convert(content).toString();
    await assets.synchronize([
      for (final filename in ['bill.pdf', 'photo.jpg'])
        {
          'kind': 'event',
          'source': 'expense_app',
          'event_type': 'image',
          'payload': {'path': '/data/1/$filename', 'sha256': hash},
        },
      {
        'kind': 'event',
        'source': 'bofa',
        'event_type': 'transaction',
        'payload': {},
      },
    ]);
    expect(requests, 2);
    offline = true;
    expect(await assets.read('photo.jpg', hash: hash), content);
    expect(requests, 2);
  });
}
