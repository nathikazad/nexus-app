import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';

import '../offline_fixtures.dart';

typedef RemoteGatewayFactory = Future<RemoteDocumentGateway> Function();

void runRemoteDocumentGatewayContract({
  required RemoteGatewayFactory createGateway,
}) {
  late RemoteDocumentGateway gateway;

  setUp(() async {
    gateway = await createGateway();
  });

  test('create is idempotent for the same operation key', () async {
    final request = RemoteCreateRequest(
      key: const DocumentKey(localId: 'local-create'),
      document: offlineTestDocument(id: 0, body: 'created'),
    );

    final first = await gateway.createDocument(
      request,
      idempotencyKey: 'create-operation',
    );
    final replay = await gateway.createDocument(
      request,
      idempotencyKey: 'create-operation',
    );

    expect(first.key.localId, 'local-create');
    expect(first.key.remoteId, isNotNull);
    expect(replay.key.remoteId, first.key.remoteId);
    expect(replay.revision, first.revision);
  });

  test('update requires the current remote revision', () async {
    final created = await gateway.createDocument(
      RemoteCreateRequest(
        key: const DocumentKey(localId: 'local-update'),
        document: offlineTestDocument(id: 0),
      ),
      idempotencyKey: 'create-for-update',
    );

    final updated = await gateway.updateDocument(
      RemoteUpdateRequest(
        key: created.key,
        document: offlineTestDocument(
          id: created.key.remoteId!,
          body: 'updated',
        ),
      ),
      idempotencyKey: 'update-operation',
      expectedRevision: created.revision,
    );

    expect(updated.revision, isNot(created.revision));
    await expectLater(
      gateway.updateDocument(
        RemoteUpdateRequest(
          key: created.key,
          document: offlineTestDocument(
            id: created.key.remoteId!,
            body: 'stale',
          ),
        ),
        idempotencyKey: 'different-stale-operation',
        expectedRevision: created.revision,
      ),
      throwsA(
        isA<RemoteGatewayException>().having(
          (error) => error.failure.kind,
          'failure kind',
          SyncFailureKind.conflict,
        ),
      ),
    );
  });

  test('update replay returns the first committed result', () async {
    final created = await gateway.createDocument(
      RemoteCreateRequest(
        key: const DocumentKey(localId: 'local-replay'),
        document: offlineTestDocument(id: 0),
      ),
      idempotencyKey: 'replay-create',
    );
    final request = RemoteUpdateRequest(
      key: created.key,
      document: offlineTestDocument(id: created.key.remoteId!, body: 'once'),
    );

    final first = await gateway.updateDocument(
      request,
      idempotencyKey: 'replay-update',
      expectedRevision: created.revision,
    );
    final replay = await gateway.updateDocument(
      request,
      idempotencyKey: 'replay-update',
      expectedRevision: created.revision,
    );

    expect(replay.revision, first.revision);
  });

  test('pull cursor returns only later changes', () async {
    await gateway.createDocument(
      RemoteCreateRequest(
        key: const DocumentKey(localId: 'first'),
        document: offlineTestDocument(id: 0, title: 'First'),
      ),
      idempotencyKey: 'first-create',
    );
    final firstPull = await gateway.pullChanges(cursor: null);
    expect(
      firstPull.documents.map((row) => row.key.localId),
      contains('first'),
    );

    await gateway.createDocument(
      RemoteCreateRequest(
        key: const DocumentKey(localId: 'second'),
        document: offlineTestDocument(id: 0, title: 'Second'),
      ),
      idempotencyKey: 'second-create',
    );
    final secondPull = await gateway.pullChanges(cursor: firstPull.nextCursor);

    expect(secondPull.documents.map((row) => row.key.localId), <String>[
      'second',
    ]);
  });

  test('opaque revision values remain transport-neutral', () {
    expect(const RemoteRevision('etag:value'), isNotNull);
  });
}
