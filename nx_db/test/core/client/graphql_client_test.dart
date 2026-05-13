@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

void main() {
  test('createClient returns GraphQLClient', () {
    final c = createClient('http://127.0.0.1:5001/graphql', '1');
    expect(c, isNotNull);
  });

  test('dbAuditContextLink adds audit headers to mutations', () async {
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

    final headers = captured!.context.entry<HttpLinkHeaders>()!.headers;
    expect(headers['X-Nexus-Operation-Id'], 'operation-1');
    expect(headers['X-Nexus-Source-Kind'], 'nx_time');
    expect(headers['X-Nexus-Source-Id'], 'action-1');
    expect(headers['X-Nexus-Source-Label'], 'create Work');
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

    final headers = captured!.context.entry<HttpLinkHeaders>()!.headers;
    expect(headers['X-Nexus-Operation-Id'], 'operation-2');
    expect(headers['X-Nexus-Source-Kind'], 'nx_time');
    expect(headers['X-Nexus-Source-Id'], 'set_kgql_models:Work');
    expect(headers['X-Nexus-Source-Label'], 'create Work');
  });
}
