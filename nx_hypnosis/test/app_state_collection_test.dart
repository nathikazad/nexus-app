import 'package:flutter_test/flutter_test.dart';
import 'package:nx_hypnosis/remote_collection.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test(
    'equal root keeps collection without another payload download',
    () async {
      var downloads = 0;
      final session = AppSyncSession(
        app: 'hypnosis',
        request: (operation, variables) async {
          if (operation == 'state')
            return {
              'status': 'ready',
              'revision': 1,
              'projection_version': 3,
              'root_hash': 'r',
              'collections': {
                '': {'hash': 'h', 'parent': null, 'count': 1, 'child_count': 0},
              },
            };
          if (variables['itemIds'] != null) downloads++;
          return {
            'status': 'ready',
            'revision': 1,
            'projection_version': 3,
            'collections': {},
            'manifest': [
              {
                'id': 'model:1',
                'hash': 'h',
                'collections': [''],
              },
            ],
            'items': [
              {
                'id': 'model:1',
                'hash': 'h',
                'payload': {
                  'id': 1,
                  'name': 'Calm',
                  'model_type': {'name': 'Desire'},
                  'attributes': {'belief': 'Rest'},
                },
              },
            ],
          };
        },
      );
      final data = RemoteCollection(
        User(domainId: 1, userId: '1', preset: BackendPreset.hosted),
        stateSession: () => session,
      );
      await data.initialize();
      await data.refresh();
      expect(downloads, 1);
      expect(data.desires.single.title, 'Calm');
      data.dispose();
    },
  );
}
