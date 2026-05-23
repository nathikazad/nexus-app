@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/src/core/client/graphql_client.dart' as graphql_client;

void main() {
  test('createClient returns GraphQLClient', () {
    final c = createClient('http://127.0.0.1:5001/graphql', '1');
    expect(c, isNotNull);
  });

  test('formatGraphQlLogValue truncates large values', () {
    final value = {
      'rows': [
        for (var i = 0; i < 40; i++) {'id': i, 'body': 'x' * 800},
      ],
    };

    final formatted = graphql_client.formatGraphQlLogValue(value);

    expect(formatted.length, lessThanOrEqualTo(4100));
    expect(formatted, contains('truncated'));
    expect(formatted, isNot(contains('x' * 800)));
  });

  test('dbAuditContextLink adds audit extensions to mutations', () async {
    Request? captured;
    final captureLink = Link.function((request, [forward]) {
      captured = request;
      return Stream.value(
        Response(
          response: const {},
          data: const {'ok': true},
          context: request.context,
        ),
      );
    });
    final link = Link.from([dbAuditContextLink('nx_time'), captureLink]);

    await runWithDbAuditContext(
      const DbAuditContext(
        operationId: 'operation-1',
        sourceKind: 'nx_time',
        sourceId: 'action-1',
        sourceLabel: 'create Work',
      ),
      () => link
          .request(
            Request(
              operation: Operation(
                document: gql('mutation SaveThing { __typename }'),
                operationName: 'SaveThing',
              ),
            ),
          )
          .drain<void>(),
    );

    final extensions = captured!.context
        .entry<RequestExtensionsThunk>()!
        .getRequestExtensions(captured!);
    expect(extensions['nexusAudit'], {
      'operationId': 'operation-1',
      'sourceKind': 'nx_time',
      'sourceId': 'action-1',
      'sourceLabel': 'create Work',
    });
    expect(captured!.context.entry<HttpLinkHeaders>(), isNull);
  });

  test('dbAuditContextLink uses app source kind when helper context omits it',
      () async {
    Request? captured;
    final captureLink = Link.function((request, [forward]) {
      captured = request;
      return Stream.value(
        Response(
          response: const {},
          data: const {'ok': true},
          context: request.context,
        ),
      );
    });
    final link = Link.from([dbAuditContextLink('nx_time'), captureLink]);

    await runWithDbAuditContext(
      const DbAuditContext(
        operationId: 'operation-2',
        sourceKind: '',
        sourceId: 'set_kgql_models:Work',
        sourceLabel: 'create Work',
      ),
      () => link
          .request(
            Request(
              operation: Operation(
                document: gql('mutation SaveThing { __typename }'),
                operationName: 'SaveThing',
              ),
            ),
          )
          .drain<void>(),
    );

    final extensions = captured!.context
        .entry<RequestExtensionsThunk>()!
        .getRequestExtensions(captured!);
    expect(extensions['nexusAudit'], {
      'operationId': 'operation-2',
      'sourceKind': 'nx_time',
      'sourceId': 'set_kgql_models:Work',
      'sourceLabel': 'create Work',
    });
    expect(captured!.context.entry<HttpLinkHeaders>(), isNull);
  });
}
