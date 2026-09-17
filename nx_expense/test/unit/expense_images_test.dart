import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_expense/data/images/expense_images.dart';

class _Client extends Mock implements GraphQLClient {}

Map<String, dynamic> _row(
  String id, {
  List<Map<String, dynamic>> links = const [],
}) => {
  'id': id,
  'time': '2026-09-16T10:15:00',
  'payload': {'path': '/data/images/1/260916101500.jpg'},
  'modelTimelineEventLinksByEventTimeAndEventId': {'nodes': links},
};
Map<String, dynamic> _link(int id, String type) => {
  'modelByModelId': {
    'id': id,
    'name': '$type $id',
    'modelTypeByModelTypeId': {'name': type},
  },
};
void main() {
  setUpAll(
    () => registerFallbackValue(
      QueryOptions(document: gql('query { __typename }')),
    ),
  );
  test('standalone image retains identity and is unlinked', () {
    final image = imageFromTimeline(_row('1'));
    expect(image.id, '1');
    expect(image.filename, '260916101500.jpg');
    expect(image.isLinked, isFalse);
  });
  test('linked status includes expenses and orders, deduplicated', () {
    final image = imageFromTimeline(
      _row(
        '1',
        links: [
          _link(3, 'Expense'),
          _link(3, 'Expense'),
          _link(4, 'Order'),
          _link(5, 'Person'),
        ],
      ),
    );
    expect(image.links.map((e) => e.type), ['Expense', 'Order']);
    expect(image.isLinked, isTrue);
  });
  test(
    'gallery paginates and requests expense images without a date range',
    () async {
      final client = _Client();
      final requests = <QueryOptions>[];
      when(() => client.query(any())).thenAnswer((call) async {
        final options = call.positionalArguments.first as QueryOptions;
        requests.add(options);
        return QueryResult(
          options: options,
          source: QueryResultSource.network,
          data: {
            'allTimelineEvents': {
              'nodes': [_row('${requests.length}')],
              'pageInfo': {
                'hasNextPage': requests.length == 1,
                'endCursor': 'older',
              },
            },
          },
        );
      });
      final result = await fetchExpenseImages(client);
      expect(result.map((e) => e.id), ['1', '2']);
      expect(requests.map((r) => r.variables['after']), [null, 'older']);
      expect(requests.first.variables.containsKey('start'), isFalse);
    },
  );
  test(
    'pagination failure does not present an incomplete gallery as complete',
    () async {
      final client = _Client();
      when(() => client.query(any())).thenAnswer(
        (call) async => QueryResult(
          options: call.positionalArguments.first as QueryOptions,
          source: QueryResultSource.network,
          data: {
            'allTimelineEvents': {
              'nodes': [],
              'pageInfo': {'hasNextPage': true},
            },
          },
        ),
      );
      await expectLater(fetchExpenseImages(client), throwsStateError);
    },
  );
}
