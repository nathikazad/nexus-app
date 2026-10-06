import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:nx_people/data/meeting/meeting_transcripts.dart';
import 'package:nx_people/data/sync/people_store.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';

void main() {
  test(
    'transcript cache persists across reopen and stays in its account partition',
    () async {
      final root = await (Directory(
        '../../tmp/nx-people-transcript-tests',
      )..createSync(recursive: true)).createTemp('cache-');
      PeopleStore open(int domain) => PeopleStore(
        FileLibrary(
          database: LibraryDatabase(
            NativeDatabase(File('${root.path}/domain-$domain.sqlite')),
          ),
          files: DirectoryContentFiles(Directory('${root.path}/files-$domain')),
        ),
        AccountIdentity(
          serverId: 'test',
          userId: '1',
          domainId: domain,
          application: 'people',
        ),
      );
      final client = GraphQLClient(
        link: HttpLink('https://test.invalid/graphql'),
        cache: GraphQLCache(),
      );
      ProviderContainer container(PeopleStore store) => ProviderContainer(
        overrides: [
          graphqlClientProvider.overrideWithValue(client),
          peopleOfflineStoreProvider.overrideWithValue(store),
        ],
      );
      var store = open(7);
      var scope = container(store);
      await scope.read(meetingTranscriptsRepositoryProvider).writeCache(99, [
        {'text': 'Saved speech'},
      ]);
      scope.dispose();
      await store.close();
      store = open(7);
      scope = container(store);
      expect(
        (await scope.read(meetingTranscriptsRepositoryProvider).readCache(99))!
            .single['text'],
        'Saved speech',
      );
      scope.dispose();
      await store.close();
      store = open(8);
      scope = container(store);
      expect(
        await scope.read(meetingTranscriptsRepositoryProvider).readCache(99),
        isNull,
      );
      scope.dispose();
      await store.close();
    },
  );
}
