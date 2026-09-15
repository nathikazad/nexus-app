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
        request: (operation, variables) async {
          if (operation == 'state')
            return {
              'status': 'ready',
              'revision': 1,
              'projection_version': 1,
              'root_hash': 'r',
              'collections': {
                'all': {'hash': 'h'},
              },
            };
          if (variables['itemIds'] != null) downloads++;
          return {
            'status': 'ready',
            'revision': 1,
            'manifest': [
              {
                'id': 0,
                'hash': 'h',
                'collections': ['all'],
              },
            ],
            'items': [
              {
                'id': 0,
                'hash': 'h',
                'payload': {
                  'desires': [
                    {'id': '1', 'title': 'Calm', 'belief': 'Rest'},
                  ],
                  'tapes': [],
                },
              },
            ],
          };
        },
      );
      final data = RemoteCollection(
        User(userId: '1', preset: BackendPreset.hosted),
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
