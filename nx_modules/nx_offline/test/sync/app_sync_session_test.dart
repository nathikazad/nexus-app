import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test(
    'an equal root at a newer revision advances the download checkpoint',
    () async {
      var revision = 1;
      final session = AppSyncSession(
        request: (operation, variables) async => operation == 'state'
            ? {
                'status': 'ready',
                'revision': revision,
                'projection_version': 1,
                'root_hash': 'same',
                'collections': {},
              }
            : {
                'status': 'ready',
                'revision': revision,
                'manifest': [],
                'items': [],
              },
      );
      expect((await session.manifest())!.revision, 1);
      revision = 3;
      expect((await session.manifest())!.revision, 3);
    },
  );
  test(
    'equal root skips manifest; changed language fetches only its members',
    () async {
      var revision = 1;
      final requests = <Map<String, dynamic>>[];
      final session = AppSyncSession(
        request: (operation, variables) async {
          if (operation == 'state')
            return {
              'status': 'ready',
              'revision': revision,
              'projection_version': 1,
              'root_hash': 'root$revision',
              'collections': {
                'chinese': {'hash': 'ch$revision'},
                'malayalam': {'hash': 'ml1'},
              },
            };
          requests.add(variables);
          return {
            'status': 'ready',
            'revision': revision,
            'manifest': [
              {
                'id': 1,
                'hash': 'ch$revision',
                'collections': ['chinese'],
              },
              if (variables['collectionIds'] == null)
                {
                  'id': 2,
                  'hash': 'ml1',
                  'collections': ['malayalam'],
                },
            ],
            'items': [],
          };
        },
      );
      expect((await session.manifest())!.entries.length, 2);
      await session.manifest();
      expect(requests.length, 1);
      revision = 2;
      final changed = (await session.manifest())!;
      expect(requests.last['collectionIds'], ['chinese']);
      expect(changed.entries.map((e) => e['id']), [1, 2]);
      expect(changed.entries.first['hash'], 'ch2');
    },
  );

  test(
    'revision changes between state and snapshot do not replace manifest',
    () async {
      final session = AppSyncSession(
        request: (operation, variables) async => operation == 'state'
            ? {
                'status': 'ready',
                'revision': 1,
                'projection_version': 1,
                'root_hash': 'r',
                'collections': {},
              }
            : {'status': 'refresh_required'},
      );
      await expectLater(session.manifest(), throwsStateError);
    },
  );

  test(
    'building state retries, unsupported servers use compatibility path',
    () async {
      var status = 'building';
      final session = AppSyncSession(
        request: (_, _) async => {'status': status},
      );
      await expectLater(session.manifest(), throwsStateError);
      status = 'unsupported';
      expect(await session.manifest(), isNull);
    },
  );
}
