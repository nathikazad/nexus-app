import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/application/sync/outbox_coalescer.dart';
import 'package:nx_docs/domain/sync/pending_operation.dart';

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

    test('an edit replacing an in-flight save gets a new identity', () {
      final result = coalescer.coalesce(
        offlinePendingOperation().copyWith(
          status: PendingOperationStatus.claimed,
          leaseOwner: 'worker',
          leaseExpiresAt: DateTime.utc(2026, 1, 2),
        ),
        offlinePendingOperation(
          operationId: 'new-operation',
          body: 'newer edit',
        ),
      );

      expect(result!.operationId, 'new-operation');
      expect(result.status, PendingOperationStatus.queued);
    });
  });
}
