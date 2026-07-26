import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/sync/conflict_detector.dart';
import 'package:nx_notes/application/sync/outbox_coalescer.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

import '../../support/offline_fixtures.dart';

void main() {
  group('OutboxCoalescer', () {
    const coalescer = OutboxCoalescer();

    test('folds many updates into the oldest operation identity', () {
      var operation = offlinePendingOperation(body: 'one');
      for (var index = 2; index <= 100; index++) {
        operation = coalescer.coalesce(
          operation,
          offlinePendingOperation(
            operationId: 'operation-$index',
            body: '$index',
            createdAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: index)),
          ),
        )!;
      }

      expect(operation.operationId, 'operation-1');
      expect(operation.payload['body'], '100');
      expect(operation.attemptCount, 0);
    });

    test('keeps create semantics when create is followed by update', () {
      final result = coalescer.coalesce(
        offlinePendingOperation(type: PendingOperationType.create),
        offlinePendingOperation(
          operationId: 'update',
          type: PendingOperationType.update,
          body: 'new',
        ),
      );

      expect(result!.type, PendingOperationType.create);
      expect(result.payload['body'], 'new');
    });

    test('create followed by delete has no remote effect', () {
      expect(
        coalescer.coalesce(
          offlinePendingOperation(type: PendingOperationType.create),
          offlinePendingOperation(type: PendingOperationType.delete),
        ),
        isNull,
      );
    });

    test('rejects operations for different documents', () {
      expect(
        () => coalescer.coalesce(
          offlinePendingOperation(),
          offlinePendingOperation(localId: 'other'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('PullResolutionPolicy', () {
    const policy = PullResolutionPolicy();

    test('inserts unseen remote documents', () {
      expect(
        policy.resolve(
          localExists: false,
          localState: null,
          baseRevision: null,
          incomingRevision: const RemoteRevision('remote-1'),
        ),
        PullResolution.insertRemote,
      );
    });

    test('replaces a clean local copy', () {
      expect(
        policy.resolve(
          localExists: true,
          localState: DocumentSyncState.synced,
          baseRevision: const RemoteRevision('old'),
          incomingRevision: const RemoteRevision('new'),
        ),
        PullResolution.replaceLocal,
      );
    });

    test('detects divergent dirty content', () {
      expect(
        policy.resolve(
          localExists: true,
          localState: DocumentSyncState.queued,
          baseRevision: const RemoteRevision('old'),
          incomingRevision: const RemoteRevision('new'),
        ),
        PullResolution.conflict,
      );
    });

    test('keeps dirty local content when remote base is unchanged', () {
      expect(
        policy.resolve(
          localExists: true,
          localState: DocumentSyncState.queued,
          baseRevision: const RemoteRevision('same'),
          incomingRevision: const RemoteRevision('same'),
        ),
        PullResolution.keepLocal,
      );
    });
  });
}
