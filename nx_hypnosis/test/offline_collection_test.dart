import 'package:nx_hypnosis/desires.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:nx_hypnosis/offline_cache.dart';
import 'package:nx_hypnosis/remote_collection.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';

Map<String, dynamic> snapshot({String recording = 'v1'}) => {
  'desires': [
    {'id': '1', 'title': 'Calm', 'belief': 'I can rest.'},
  ],
  'tapes': [
    {
      'id': '2',
      'desire_id': '1',
      'title': 'Evening',
      'story': 'Relax.',
      'audio': {'link': '/hypnosis/recordings/2', 'filename': recording},
    },
  ],
};

Future<HypnosisCache> cache(Directory directory, String account) async =>
    HypnosisCache(
      FileLibrary(
        database: LibraryDatabase(
          NativeDatabase(File('${directory.path}/$account.sqlite')),
        ),
        files: DirectoryContentFiles(
          Directory('${directory.path}/$account-content'),
        ),
      ),
      DirectoryBinaryContentFiles('${directory.path}/$account-audio'),
    );

RemoteCollection collection(
  HypnosisCache cache,
  Future<http.Response> Function(http.Request) respond,
) => RemoteCollection(
  User(userId: '1', preset: BackendPreset.hosted),
  cache: cache,
  transport: NexusAuthenticatedClient(
    preset: BackendPreset.hosted,
    userId: '1',
    authHeaders: (_) async => {},
    inner: MockClient(respond),
  ),
);

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nx-hypnosis-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'interrupted download never publishes a partial recording and can retry',
    () async {
      final store = await cache(directory, 'account');
      final tape = Tape(
        id: '2',
        desireId: '1',
        title: 'Evening',
        story: '',
        audioAsset: '/recording',
      );
      Stream<List<int>> interrupted() async* {
        yield [1, 2];
        throw const SocketException('Connection lost');
      }

      await expectLater(
        store.saveRecording(tape, interrupted()),
        throwsA(isA<SocketException>()),
      );
      expect(await store.recordingPath(tape), isNull);
      final path = await store.saveRecording(tape, Stream.value([1, 2, 3]));
      expect(await File(path).readAsBytes(), [1, 2, 3]);
      await store.close();
    },
  );

  test(
    'cold offline restart restores stories and playable recordings without network',
    () async {
      final store = await cache(directory, 'account1');
      final data = collection(
        store,
        (r) async => r.url.path.endsWith('/2')
            ? http.Response.bytes([1, 2, 3], 200)
            : http.Response(jsonEncode(snapshot()), 200),
      );
      await data.initialize();
      await data.prefetchRecordings();
      final path = await data.recordingPath(data.tapes.single);
      expect(await File(path).readAsBytes(), [1, 2, 3]);
      await data.close();
      var requests = 0;
      final reopened = collection(await cache(directory, 'account1'), (
        _,
      ) async {
        requests++;
        throw const SocketException('Offline');
      });
      await reopened.initialize();
      expect(reopened.tapes.single.story, 'Relax.');
      expect(await reopened.recordingPath(reopened.tapes.single), path);
      expect(requests, 0);
      await expectLater(reopened.refresh(), throwsA(anything));
      expect(reopened.desires.single.title, 'Calm');
      await reopened.close();
    },
  );

  test(
    'another account cannot read the saved collection or recordings',
    () async {
      final first = await cache(directory, 'first');
      await first.saveCollection(jsonEncode(snapshot()));
      await first.close();
      final second = await cache(directory, 'second');
      expect(await second.readCollection(), isNull);
      await first.close();
      await second.close();
    },
  );

  test(
    'unchanged refresh keeps the stored body and concurrent audio requests share one download',
    () async {
      final store = await cache(directory, 'account');
      var downloads = 0;
      final data = collection(store, (r) async {
        if (r.url.path.endsWith('/2')) {
          downloads++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response.bytes([1, 2, 3], 200);
        }
        return http.Response(jsonEncode(snapshot()), 200);
      });
      await data.refresh();
      final before = await store.library.metadata('hypnosis', 'collection');
      await Future.wait([
        data.recordingPath(data.tapes.single),
        data.recordingPath(data.tapes.single),
        data.prefetchRecordings(),
      ]);
      await data.refresh();
      await data.prefetchRecordings();
      expect(downloads, 1);
      expect(
        (await store.library.metadata('hypnosis', 'collection'))!.reference,
        before!.reference,
      );
      await data.close();
    },
  );

  test(
    'changed audio metadata refreshes the recording even with the same URL',
    () async {
      var version = 'v1';
      var downloads = 0;
      final data = collection(await cache(directory, 'account'), (r) async {
        if (r.url.path.endsWith('/2')) {
          downloads++;
          return http.Response.bytes([downloads], 200);
        }
        return http.Response(jsonEncode(snapshot(recording: version)), 200);
      });
      await data.refresh();
      await data.prefetchRecordings();
      final old = await data.recordingPath(data.tapes.single);
      version = 'v2';
      await data.refresh();
      await data.prefetchRecordings();
      final next = await data.recordingPath(data.tapes.single);
      expect(next, isNot(old));
      expect(downloads, 2);
      await data.close();
    },
  );

  test(
    'corrupt recording is downloaded again; failed collection never erases saved data',
    () async {
      var broken = false;
      final data = collection(
        await cache(directory, 'account'),
        (r) async => r.url.path.endsWith('/2')
            ? http.Response.bytes([1, 2, 3], 200)
            : http.Response(
                broken ? '{"desires":[]}' : jsonEncode(snapshot()),
                200,
              ),
      );
      await data.refresh();
      await data.prefetchRecordings();
      final path = await data.recordingPath(data.tapes.single);
      await File(path).writeAsBytes([3, 2, 1]);
      expect(
        await File(await data.recordingPath(data.tapes.single)).readAsBytes(),
        [1, 2, 3],
      );
      broken = true;
      await expectLater(data.refresh(), throwsA(anything));
      expect(data.desires.single.title, 'Calm');
      await data.close();
    },
  );
}
