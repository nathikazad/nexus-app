import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:nx_people/data/sync/people_assets.dart';
import 'package:nx_people/data/sync/people_store.dart';
import 'package:nx_people/data/sync/people_transport.dart';

void main() {
  test(
    'offline photo survives reopen and upload result is reused with absolute URLs',
    () async {
      final directory = await (Directory(
        '../../tmp/nx-people-sync',
      )..createSync(recursive: true)).createTemp('assets-');
      PeopleStore open() => PeopleStore(
        FileLibrary(
          database: LibraryDatabase(
            NativeDatabase(File('${directory.path}/db')),
          ),
          files: DirectoryContentFiles(Directory('${directory.path}/files')),
        ),
        const AccountIdentity(
          serverId: 'test',
          userId: '1',
          domainId: 7,
          application: 'people',
        ),
      );
      var store = open();
      var uploads = 0;
      final reads = AppReads(
        MockClient((request) async {
          if (request.method != 'POST') {
            throw StateError('Must read from local disk');
          }
          expect(request.body, contains('7'));
          uploads++;
          return http.Response(
            jsonEncode({'url': '/nx_people/assets/7/test.png'}),
            200,
          );
        }),
        Uri.parse('https://nexus.test'),
        'people',
      );
      final files = DirectoryBinaryContentFiles('${directory.path}/binary');
      var assets = PeopleAssets(
        PeopleTransport(reads),
        7,
        store: store,
        files: files,
      );
      final url = await assets.stage([1, 2, 3, 4], 'photo.png');
      expect(uploads, 0);
      expect(await assets.read(url), [1, 2, 3, 4]);
      await store.close();
      store = open();
      assets = PeopleAssets(
        PeopleTransport(reads),
        7,
        store: store,
        files: files,
      );
      final resolved = await assets.resolve({
        'attributes': [
          {'key': 'image_url', 'value': url},
        ],
      });
      expect(
        resolved['attributes'][0]['value'],
        '/nx_people/assets/7/test.png',
      );
      expect(await assets.uploadLocal(url), '/nx_people/assets/7/test.png');
      expect(uploads, 1);
      expect(
        await assets.read('https://nexus.test/nx_people/assets/7/test.png'),
        [1, 2, 3, 4],
      );
      await expectLater(
        assets.read('https://external.test/private'),
        throwsStateError,
      );
      await store.close();
      await reads.close();
      await directory.delete(recursive: true);
    },
  );
}
