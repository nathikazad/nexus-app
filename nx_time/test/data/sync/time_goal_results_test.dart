import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:nx_time/data/sync/time_store.dart';
import 'package:nx_time/data/sync/time_goal_results.dart';

void main() {
  test(
    'first download, changed results, filtered goal and offline restart use durable snapshot',
    () async {
      final dir = await Directory.systemTemp.createTemp('time-goal-cache');
      TimeStore openStore() => TimeStore(
        FileLibrary(
          database: LibraryDatabase(
            NativeDatabase(File('${dir.path}/cache.sqlite')),
          ),
          files: DirectoryContentFiles(dir),
        ),
        const AccountIdentity(
          serverId: 'test',
          userId: '1',
          domainId: 1,
          application: 'time',
        ),
      );
      var store = openStore();
      var count = 4;
      var online = true;
      var requests = 0;
      Future<void> request(List<String> months, DateTime now) async {
        if (!online) throw StateError('offline');
        requests++;
        expect(months, contains('2026-10-01'));
        expect(now.isUtc, isFalse);
      }

      Future<void> pull() async {
        await store.library.saveRemote(
          'time_goal_results',
          'snapshot',
          jsonEncode({
            'goal-result:month_score:2026-10-01': {
              'hash': 'score$count',
              'payload': {
                'view': 'month_score',
                'period_start': '2026-10-01',
                'result': {'month_start': '2026-10-01', 'days': []},
              },
            },
            'goal-result:week:2026-10-26:5': {
              'hash': 'goal$count',
              'payload': {
                'view': 'week',
                'period_start': '2026-10-26',
                'goal_id': 5,
                'result': {'id': 5, 'label': 'Prayer', 'value': count},
              },
            },
          }),
        );
      }

      final cache = TimeGoalResults(store, requestMonths: request, pull: pull);
      final start = DateTime(2026, 10, 26);
      expect((await cache.read('week', start, null))['items'][0]['value'], 4);
      count = 5;
      await cache.refresh();
      expect((await cache.read('week', start, 5))['items'][0]['value'], 5);
      expect((await cache.read('week', start, 999))['items'], isEmpty);
      await cache.close();
      await store.close();
      store = openStore();
      online = false;
      final reopened = TimeGoalResults(
        store,
        requestMonths: request,
        pull: pull,
      );
      expect(
        (await reopened.read('week', start, null))['items'][0]['value'],
        5,
      );
      expect(requests, 2);
      await reopened.close();
      await store.close();
      await dir.delete(recursive: true);
    },
  );
}
