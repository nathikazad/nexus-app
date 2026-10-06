import 'dart:io';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/testing.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:nx_people/data/sync/people_data_repository.dart';
import 'package:nx_people/data/sync/people_store.dart';
import 'package:nx_people/data/sync/people_transport.dart';
import 'package:nx_people/data/person/kgql_people_repository.dart';
import 'package:nx_people/data/log/kgql_log_repository.dart';
import 'package:nx_people/data/meeting/kgql_meeting_repository.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';
import 'package:nx_people/domain/log/daily_log.dart';
import 'package:nx_people/domain/meeting/meeting_repository.dart';

void main() {
  late Directory directory;
  late PeopleStore store;
  late PeopleDataRepository data;
  late AppReads reads;
  late KgqlPeopleRepository people;
  final client = GraphQLClient(
    link: HttpLink('https://test.invalid/graphql'),
    cache: GraphQLCache(),
  );
  setUp(() async {
    directory = await (Directory(
      '../../tmp/nx-people-sync',
    )..createSync(recursive: true)).createTemp('repository-');
    final library = FileLibrary(
      database: LibraryDatabase(
        NativeDatabase(File('${directory.path}/store.sqlite')),
      ),
      files: DirectoryContentFiles(Directory('${directory.path}/files')),
    );
    store = PeopleStore(
      library,
      const AccountIdentity(
        serverId: 'test',
        userId: '1',
        domainId: 7,
        application: 'people',
      ),
    );
    reads = AppReads(
      MockClient((_) async => throw const SocketException('Offline')),
      Uri.parse('https://test.invalid'),
      'people',
    );
    data = PeopleDataRepository(
      reads: reads,
      remote: PeopleTransport(reads),
      domainId: 7,
      store: store,
    );
    final schemas = [
      for (final name in [
        'Person',
        'Contact',
        'Meet',
        'Daily Log',
        'Conversation',
        'Company',
      ])
        {'id': 1, 'name': name},
    ];
    await store.applySnapshot(
      [
        {
          'id': 0,
          'hash': 'schema',
          'payload': {'id': 0, 'kind': 'metadata', 'schemas': schemas},
        },
      ],
      {0},
    );
    await library.saveRemote('people_state', 'coverage', '{}');
    people = KgqlPeopleRepository(
      client: client,
      data: data,
      loadPersonSchema: () => data.schema('Person'),
    );
  });
  tearDown(() async {
    await store.close();
    await reads.close();
    await directory.delete(recursive: true);
  });

  test(
    'recent people sort by creation before limiting, not name or edits',
    () async {
      final rows = [
        {
          'id': 1,
          'name': 'Alice',
          'created_at': '2026-10-01T10:00:00Z',
          'updated_at': '2026-10-10T10:00:00Z',
        },
        {'id': 2, 'name': 'Katie', 'created_at': '2026-10-06T08:00:00-07:00'},
        {'id': 3, 'name': 'Zoe', 'created_at': '2026-10-06T15:00:00Z'},
        {'id': 4, 'name': 'Missing date'},
        {'id': 5, 'name': 'Invalid date', 'created_at': 'invalid'},
      ];
      await store.acceptLive([
        for (final row in rows)
          {
            ...row,
            'kind': 'Person',
            'model_type': {'name': 'Person'},
          },
      ]);
      expect((await people.listRecent()).map((p) => p.id), [3, 2, 1, 5, 4]);
      expect((await people.listRecent(limit: 2)).map((p) => p.name), [
        'Zoe',
        'Katie',
      ]);
    },
  );

  test(
    'offline contact creation, editing, contact deletion and meeting stay readable',
    () async {
      final id = await people.createPerson(
        const PersonDraft(
          name: 'Alice',
          summary: 'Met today',
          contacts: [PersonContact(type: 'phone', value: '123')],
        ),
      );
      expect(id, greaterThan(2147483647));
      final alice = (await people.getById(id))!;
      expect(alice.name, 'Alice');
      expect(alice.contacts.single.value, '123');
      await people.updatePerson(
        id,
        const PersonDraft(name: 'Alice updated', summary: 'New notes'),
      );
      expect((await people.getById(id))!.contacts, isEmpty);
      final meetings = KgqlMeetingRepository(client: client, data: data);
      await meetings.create(
        MeetingDraft(
          personId: id,
          title: 'Lunch',
          description: '',
          startedAt: DateTime(2026, 9, 26, 12),
        ),
      );
      expect((await people.getById(id))!.meetings, contains('Lunch'));
      expect(await store.pendingMutations(), isNotEmpty);
    },
  );

  test('daily log offline reads preserve calendar boundaries', () async {
    final logs = KgqlLogRepository(client: client, data: data);
    await logs.create(
      DailyLogDraft(loggedAt: DateTime(2026, 9, 26, 23, 59), entry: 'Today'),
    );
    await logs.create(
      DailyLogDraft(loggedAt: DateTime(2026, 9, 27), entry: 'Tomorrow'),
    );
    expect(
      (await logs.listForCalendarDay(DateTime(2026, 9, 26))).single.entry,
      'Today',
    );
  });

  test(
    'temporary relation IDs resolve once and retry sends identical request',
    () async {
      final id = await people.createPerson(
        const PersonDraft(
          name: 'Alice',
          summary: '',
          contacts: [PersonContact(type: 'phone', value: '123')],
        ),
      );
      var pending = await store.pendingMutations();
      final createPerson = pending[0],
          createContact = pending[1],
          link = pending[2];
      for (final entry in [
        (createPerson, 11, 'Person'),
        (createContact, 12, 'Contact'),
      ]) {
        final local = await store.get(entry.$1.payload['local_id'] as String);
        await store.complete(
          MutationReceipt(
            operationId: entry.$1.operationId,
            entityKey: EntityKey(
              localId: entry.$1.payload['local_id'] as String,
              remoteId: entry.$2,
            ),
            revision: const Revision('r1'),
            metadata: {
              'result': {
                'status': 'applied',
                'id': entry.$2,
                'entity': {...local!, 'id': entry.$2, 'revision': 'r1'},
              },
            },
          ),
        );
      }
      final wire = await store.freeze(link);
      expect(wire['domain_id'], 7);
      expect(wire['data']['id'], 11);
      expect(wire['data']['relations'][0]['link'], [12]);
      expect(await store.freeze(link), wire);
      expect((await people.getById(id))!.contacts.single.value, '123');
    },
  );

  test(
    'conflict resolution keeps newer local edit and rebases only on explicit choice',
    () async {
      await store.acceptLive([
        {
          'id': 9,
          'name': 'Original',
          'kind': 'Person',
          'model_type_id': 1,
          'revision': 'r1',
        },
      ]);
      await data.set(SetModelRequest(id: 9, name: 'Local'));
      final first = (await store.pendingMutations()).single;
      await data.set(SetModelRequest(id: 9, description: 'Newer note'));
      await store.library.saveRemote(
        'people_conflicts',
        first.operationId,
        jsonEncode({
          'status': 'conflict',
          'id': 9,
          'entity': {
            'id': 9,
            'name': 'Remote',
            'kind': 'Person',
            'model_type_id': 1,
            'revision': 'r2',
          },
        }),
      );
      await store.fail(
        first.operationId,
        failure: const SyncFailure(
          kind: SyncFailureKind.conflict,
          message: 'Conflict',
        ),
        retryAt: DateTime.now(),
      );
      await store.resolveConflict(
        first.operationId,
        keepLocal: true,
        replacementId: 'replacement-operation',
      );
      final wire = await store.freeze((await store.pendingMutations()).single);
      expect(wire['expected_revision'], 'r2');
      expect(wire['data']['name'], 'Local');
      expect(wire['data']['description'], 'Newer note');
      expect((await data.get(9))!['name'], 'Local');
    },
  );
  test(
    'offline conversation import links the profile and exposes queued messages',
    () async {
      final personId = await people.createPerson(
        const PersonDraft(name: 'Alice', summary: ''),
      );
      final result = await data.conversation({
        'person_id': personId,
        'provider': 'wechat',
        'external_account_id': 'primary',
        'external_thread_id': 'thread',
        'name': 'Thread',
        'summary': 'Offline import',
        'response_pending': true,
        'messages': [
          {
            'external_message_id': 'm1',
            'raw_payload': {'body': 'Hello', 'id': 987654321012345},
          },
        ],
      });
      final person = (await people.getById(personId))!;
      expect(person.conversations.single.id, result['conversation_id']);
      expect(
        (await data.messages(
          result['conversation_id'] as int,
        )).single['message']['rawPayload']['body'],
        'Hello',
      );
      final pending = await store.pendingMutations();
      await expectLater(store.freeze(pending.last), throwsStateError);
      final local = await store.get('$personId');
      await store.complete(
        MutationReceipt(
          operationId: pending.first.operationId,
          entityKey: EntityKey(localId: '$personId', remoteId: 71),
          revision: const Revision('r1'),
          metadata: {
            'result': {
              'status': 'applied',
              'id': 71,
              'entity': {...local!, 'id': 71, 'revision': 'r1'},
            },
          },
        ),
      );
      final wire = await store.freeze(pending.last);
      expect(wire['data']['_conversation']['person_id'], 71);
      expect(
        wire['data']['_conversation']['messages'][0]['raw_payload']['id'],
        987654321012345,
      );
    },
  );
}
