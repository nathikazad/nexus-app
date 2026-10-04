import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_sync/nx_sync.dart';

class Server {
  int revision = 1;
  bool interrupted = false;
  final nodes = <String, Map<String, dynamic>>{};
  final records = <int, Map<String, dynamic>>{};
  final requests = <List<String>>[];
  Map<String, dynamic>? persisted;
  void group(String id, String? parent) => nodes[id] = {'parent': parent};
  void record(int id, String group, String hash) => records[id] = {
    'id': id,
    'hash': hash,
    'collections': [group],
    'model_type': 'Task',
  };
  Map<String, dynamic> summary(String key) {
    final children =
        nodes.keys.where((k) => k != '' && nodes[k]!['parent'] == key).toList()
          ..sort();
    final own = records.values
        .where((r) => (r['collections'] as List).contains(key))
        .toList();
    return {
      'parent': nodes[key]!['parent'],
      'hash': jsonEncode([
        own,
        [
          for (final c in children) [c, summary(c)['hash']],
        ],
      ]),
      'count': own.length,
      'child_count': children.length,
      'metadata': {},
    };
  }

  Future<Map<String, dynamic>> request(
    String op,
    Map<String, dynamic> args,
  ) async {
    if (op == 'state')
      return {
        'status': 'ready',
        'projection_version': 2,
        'revision': revision,
        'root_hash': summary('')['hash'],
        'collections': {'': summary('')},
      };
    if (interrupted) return {'status': 'refresh_required'};
    final selected = (args['collectionIds'] as List).cast<String>();
    requests.add(selected);
    return {
      'status': 'ready',
      'projection_version': 2,
      'revision': revision,
      'collections': {
        for (final k in nodes.keys)
          if (k != '' && selected.contains(nodes[k]!['parent'])) k: summary(k),
      },
      'manifest': [
        for (final r in records.values)
          if ((r['collections'] as List).any(selected.contains)) r,
      ],
      'items': [
        for (final id in args['itemIds'] as List? ?? [])
          {
            'id': id,
            'hash': records[id]!['hash'],
            'payload': {'id': id},
          },
      ],
    };
  }

  AppSyncSession session() => AppSyncSession(
    request: request,
    load: () async => persisted,
    save: (data) async => persisted = jsonDecode(jsonEncode(data)),
  );
}

void main() {
  test(
    'nested sync skips unchanged years after restart and downloads only changed body',
    () async {
      final s = Server()
        ..group('', null)
        ..group('2025', '')
        ..group('2025-01', '2025')
        ..group('2025-01-01', '2025-01')
        ..group('2026', '')
        ..group('2026-10', '2026')
        ..group('2026-10-03', '2026-10')
        ..record(1, '2025-01-01', 'a')
        ..record(2, '2026-10-03', 'b');
      await s.session().manifest();
      s.requests.clear();
      final client = s.session();
      await client.manifest();
      expect(s.requests, isEmpty);
      s.revision++;
      s.record(2, '2026-10-03', 'c');
      final changed = (await client.manifest())!;
      expect(s.requests, [
        [''],
        ['2026'],
        ['2026-10'],
        ['2026-10-03'],
      ]);
      expect(changed.entries.map((e) => e['id']), [1, 2]);
      expect((await client.download(changed, {2})).single['hash'], 'c');
    },
  );
  test(
    'moving a record and removing its old branch preserves one copy',
    () async {
      final s = Server()
        ..group('', null)
        ..group('old', '')
        ..record(1, 'old', 'a');
      final client = s.session();
      await client.manifest();
      s.nodes.remove('old');
      s.group('new', '');
      s.record(1, 'new', 'a');
      s.revision++;
      final changed = (await client.manifest())!;
      expect(changed.collections.containsKey('old'), false);
      expect(changed.entries.single['id'], 1);
      s.nodes.remove('new');
      s.records.clear();
      s.revision++;
      expect((await client.manifest())!.entries, isEmpty);
    },
  );
  test('direct root records and flat groups use the same protocol', () async {
    final s = Server()
      ..group('', null)
      ..group('language', '')
      ..record(1, '', 'a')
      ..record(2, 'language', 'b');
    s.records[2]!['collections'] = ['', 'language'];
    final client = s.session();
    expect((await client.manifest())!.entries.length, 2);
    s.requests.clear();
    s.revision++;
    expect((await client.manifest())!.revision, 2);
    expect(s.requests, isEmpty);
  });
  test(
    'interrupted revision never overwrites a persisted checkpoint',
    () async {
      final s = Server()
        ..group('', null)
        ..record(1, '', 'a');
      final client = s.session();
      await client.manifest();
      final before = jsonEncode(s.persisted);
      s.record(1, '', 'b');
      s.revision++;
      s.interrupted = true;
      await expectLater(client.manifest(), throwsStateError);
      expect(jsonEncode(s.persisted), before);
      s.interrupted = false;
      expect((await client.manifest())!.entries.single['hash'], 'b');
    },
  );
  test('incomplete branch and obsolete protocol are rejected', () async {
    final s = Server()
      ..group('', null)
      ..record(1, '', 'a');
    final client = AppSyncSession(
      request: (op, args) async {
        final result = await s.request(op, args);
        if (op == 'snapshot') result['manifest'] = [];
        return result;
      },
    );
    await expectLater(client.manifest(), throwsStateError);
    await expectLater(
      AppSyncSession(
        request: (_, _) async => {'status': 'ready', 'projection_version': 1},
      ).manifest(),
      throwsStateError,
    );
  });
}
