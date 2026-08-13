import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  const account = AccountIdentity(
    serverId: 'production',
    userId: 'user-1',
    application: 'test',
  );
  final createdAt = DateTime.utc(2026, 7, 26);

  PendingMutation mutation(
    String operationId,
    MutationType type,
    String value,
  ) {
    return PendingMutation(
      operationId: operationId,
      account: account,
      collection: 'items',
      entityKey: const EntityKey(localId: 'item-1'),
      type: type,
      payload: {'value': value},
      createdAt: createdAt,
    );
  }

  test(
    'updates coalesce into oldest operation identity and newest payload',
    () {
      const policy = OutboxCoalescer();
      final result = policy.coalesce(
        mutation('oldest', MutationType.update, 'old'),
        mutation('newest', MutationType.update, 'new'),
      );

      expect(result?.operationId, 'oldest');
      expect(result?.payload, {'value': 'new'});
    },
  );

  test('create followed by update remains a create', () {
    const policy = OutboxCoalescer();
    final result = policy.coalesce(
      mutation('create', MutationType.create, 'old'),
      mutation('update', MutationType.update, 'new'),
    );

    expect(result?.type, MutationType.create);
    expect(result?.operationId, 'create');
    expect(result?.payload, {'value': 'new'});
  });

  test('create followed by delete has no remote effect', () {
    const policy = OutboxCoalescer();
    final result = policy.coalesce(
      mutation('create', MutationType.create, 'value'),
      mutation('delete', MutationType.delete, ''),
    );

    expect(result, isNull);
  });

  test('repeated deletes retain the durable operation identity', () {
    const policy = OutboxCoalescer();
    final result = policy.coalesce(
      mutation('oldest', MutationType.delete, 'old'),
      mutation('newest', MutationType.delete, 'new'),
    );

    expect(result?.operationId, 'oldest');
    expect(result?.payload, {'value': 'new'});
  });

  test('relation and entity operations require separate aggregate keys', () {
    const policy = OutboxCoalescer();

    expect(
      () => policy.coalesce(
        mutation('update', MutationType.update, 'value'),
        mutation('relation', MutationType.relation, 'relation'),
      ),
      throwsStateError,
    );
  });

  test('retry policy doubles delay and caps it', () {
    const policy = RetryPolicy(
      baseDelay: Duration(seconds: 2),
      maxDelay: Duration(seconds: 5),
    );
    final now = DateTime.utc(2026, 7, 26);

    expect(policy.retryAt(now, 1), now.add(const Duration(seconds: 2)));
    expect(policy.retryAt(now, 2), now.add(const Duration(seconds: 4)));
    expect(policy.retryAt(now, 3), now.add(const Duration(seconds: 5)));
  });
}
