import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_sync/nx_sync.dart';
import 'package:nx_sync/src/record_graph.dart';

Map<String, dynamic> model(
  int id,
  String name,
  String type, {
  Map<String, dynamic> attributes = const {},
  List<Map<String, dynamic>> relations = const [],
}) => {
  'id': id,
  'name': name,
  'model_type': {'id': id, 'name': type},
  'families': [type],
  'attributes': attributes,
  'relations': relations,
};

class Server {
  int revision = 1;
  final bodies = <String, Map<String, dynamic>>{};
  final hashes = <String, String>{};
  final support = <String>{};
  final downloaded = <String>[];
  Map<String, dynamic>? saved;
  bool fail = false;
  Future<Map<String, dynamic>> request(
    String operation,
    Map<String, dynamic> args,
  ) async {
    final base = {
      'status': 'ready',
      'revision': revision,
      'projection_version': 3,
    };
    if (operation == 'state')
      return {
        ...base,
        'root_hash': 'root$revision',
        'collections': {
          '': {
            'hash': 'group$revision',
            'count': bodies.length,
            'child_count': 0,
            'parent': null,
          },
        },
      };
    final keys = (args['itemIds'] as List?)?.cast<String>();
    if (keys != null) {
      if (fail) throw StateError('Offline');
      downloaded.addAll(keys);
      return {
        ...base,
        'items': [
          for (final key in keys)
            {'id': key, 'hash': hashes[key], 'payload': bodies[key]},
        ],
      };
    }
    return {
      ...base,
      'collections': {},
      'manifest': [
        for (final key in bodies.keys)
          {
            'id': key,
            'hash': hashes[key],
            'collections': [''],
            'role': support.contains(key) ? 'support' : 'primary',
            'model_type': bodies[key]!['model_type']?['name'],
          },
      ],
    };
  }

  AppSyncSession session(String app) => AppSyncSession(
    app: app,
    request: request,
    load: () async => saved,
    save: (value) async => saved = jsonDecode(jsonEncode(value)),
  );
  void put(int id, String hash, Map<String, dynamic> value) {
    bodies['model:$id'] = value;
    hashes['model:$id'] = hash;
  }
}

void main() {
  test(
    'renaming a neighbor downloads only that model and refreshes the local meeting view',
    () async {
      final s = Server();
      s.put(
        1,
        'meeting',
        model(
          1,
          'Lunch',
          'Meet',
          relations: [
            {
              'model_id': 2,
              'from_id': 1,
              'to_id': 2,
              'relation_name': 'meet_person',
            },
          ],
        ),
      );
      s.put(2, 'alice', model(2, 'Alice', 'Person'));
      final client = s.session('people');
      final first = (await client.manifest())!;
      final oldHash = first.entries.firstWhere((e) => e['id'] == 1)['hash'];
      expect(
        (await client.download(first, {
          1,
        })).single['payload']['Person'][0]['name'],
        'Alice',
      );
      s.downloaded.clear();
      s.revision++;
      s.put(2, 'alex', model(2, 'Alex', 'Person'));
      final changed = (await client.manifest())!;
      expect(s.downloaded, ['model:2']);
      expect(
        changed.entries.firstWhere((e) => e['id'] == 1)['hash'],
        isNot(oldHash),
      );
      final meeting = (await client.download(changed, {1})).single['payload'];
      expect(meeting['Person'][0]['name'], 'Alex');
      expect(meeting['revision'], 'meeting');
      s.downloaded.clear();
      final restored = s.session('people');
      final afterRestart = (await restored.manifest())!;
      expect(s.downloaded, isEmpty);
      expect(
        (await restored.download(afterRestart, {
          1,
        })).single['payload']['Person'][0]['name'],
        'Alex',
      );
    },
  );
  test(
    'support records stay off the app list but hydrate card relations',
    () async {
      final s = Server();
      s.put(
        1,
        'card',
        model(
          1,
          'Word',
          'Word',
          relations: [
            {'model_id': 2, 'relation_name': 'source_book'},
          ],
        ),
      );
      s.put(2, 'book', model(2, 'My book', 'Book'));
      s.support.add('model:2');
      final session = s.session('cards');
      final manifest = (await session.manifest())!;
      expect(manifest.entries.map((e) => e['id']), [1]);
      expect(
        (await session.download(manifest, {
          1,
        })).single['payload']['relations'][0]['name'],
        'My book',
      );
    },
  );
  test(
    'failed body download keeps the old persisted checkpoint and retries',
    () async {
      final s = Server()..put(1, 'a', model(1, 'A', 'Task'));
      final session = s.session('time');
      await session.manifest();
      final saved = jsonEncode(s.saved);
      s.revision++;
      s.put(1, 'b', model(1, 'B', 'Task'));
      s.fail = true;
      await expectLater(session.manifest(), throwsStateError);
      expect(jsonEncode(s.saved), saved);
      s.fail = false;
      final next = (await session.manifest())!;
      expect(
        (await session.download(next, {1})).single['payload']['name'],
        'B',
      );
    },
  );
  test(
    'missing cached model is repaired even when its manifest hash is unchanged',
    () async {
      final s = Server()..put(1, 'a', model(1, 'A', 'Task'));
      await s.session('time').manifest();
      (s.saved!['bodies'] as Map).clear();
      s.downloaded.clear();
      await s.session('time').manifest();
      expect(s.downloaded, ['model:1']);
    },
  );
  test(
    'deletion removes a supporting record and its hydrated relation',
    () async {
      final s = Server();
      s.put(
        1,
        'a',
        model(
          1,
          'A',
          'Person',
          relations: [
            {'model_id': 2},
          ],
        ),
      );
      s.put(2, 'b', model(2, 'B', 'Person'));
      s.support.add('model:2');
      final session = s.session('people');
      await session.manifest();
      s.revision++;
      s.bodies.remove('model:2');
      s.hashes.remove('model:2');
      final result = (await session.manifest())!;
      expect(
        (await session.download(result, {1})).single['payload']['relations'],
        isEmpty,
      );
    },
  );
  test(
    'document transcripts and expense event details resolve from references',
    () {
      final docs = RecordGraph(
        {
          'model:1': model(
            1,
            'Book',
            'Book',
            attributes: {
              'book_file': {'transcript_id': 2},
            },
            relations: [
              {'model_id': 2},
            ],
          ),
          'model:2': model(
            2,
            'Conversation',
            'Transcript',
            attributes: {
              'messages': {
                'turns': ['hello'],
              },
            },
          ),
        },
        {'model:1': 'a', 'model:2': 'b'},
      ).view('books', 'model:1');
      expect(docs['transcripts'][0]['messages']['turns'], ['hello']);
      expect(docs['epub_transcript']['id'], 2);
      final expense = RecordGraph(
        {
          'model:1': model(1, 'Dinner', 'Expense'),
          'timeline:9': {
            'event_id': '9007199254740993',
            'event_time': '2026-10-03',
            'payload': {'amount': 20},
            'links': [
              {'id': '3', 'model_id': 1},
            ],
          },
        },
        {'model:1': 'x'},
      ).view('expense', 'model:1');
      expect(expense['timeline_links'][0]['event_id'], '9007199254740993');
    },
  );
}
