import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/domain/images/expense_image.dart';

const _fields = '''
  id time payload
  modelTimelineEventLinksByEventTimeAndEventId(first: 1000) {
    nodes { modelByModelId { id name modelTypeByModelTypeId { name } } }
  }
''';

ExpenseImage imageFromTimeline(Map<String, dynamic> row) {
  final payload = row['payload'] as Map? ?? {};
  final path = payload['path']?.toString() ?? '';
  final links = <ImageModelLink>[];
  final seen = <int>{};
  for (final link
      in (row['modelTimelineEventLinksByEventTimeAndEventId']?['nodes']
              as List? ??
          const [])) {
    final model = link['modelByModelId'];
    if (model is! Map) continue;
    final type = model['modelTypeByModelTypeId']?['name'];
    final id = int.tryParse('${model['id']}');
    if (id == null || !seen.add(id) || (type != 'Expense' && type != 'Order')) {
      continue;
    }
    links.add(
      ImageModelLink(
        id: id,
        name: model['name']?.toString() ?? 'Untitled',
        type: type as String,
      ),
    );
  }
  return ExpenseImage(
    id: '${row['id']}',
    time: DateTime.parse(row['time'] as String),
    filename: path.replaceAll('\\', '/').split('/').last,
    links: links,
  );
}

/// All expense-app image events, including images with no model link. Cursor
/// pagination avoids silently losing older receipts or relying on the list range.
Future<List<ExpenseImage>> fetchExpenseImages(GraphQLClient client) async {
  final images = <ExpenseImage>[];
  String? cursor;
  do {
    final result = await client.query(
      QueryOptions(
        document: gql('''
      query ExpenseImages(\$after: Cursor) {
        allTimelineEvents(first: 100, after: \$after,
          orderBy: [TIME_DESC, ID_DESC], condition: {eventType: "image", source: "expense_app"}) {
          nodes { $_fields }
          pageInfo { hasNextPage endCursor }
        }
      }
    '''),
        variables: {'after': cursor},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (result.hasException) throw result.exception!;
    final connection = result.data?['allTimelineEvents'];
    if (connection is! Map) throw StateError('Missing image list');
    for (final row in connection['nodes'] as List? ?? const []) {
      if (row is Map<String, dynamic>) images.add(imageFromTimeline(row));
    }
    final page = connection['pageInfo'] as Map? ?? {};
    if (page['hasNextPage'] != true) break;
    final next = page['endCursor'] as String?;
    if (next == null || next == cursor) {
      throw StateError('Unable to load the next image page');
    }
    cursor = next;
  } while (true);
  return images;
}

final expenseImagesProvider = FutureProvider.autoDispose<List<ExpenseImage>>(
  (ref) => fetchExpenseImages(ref.watch(expenseGraphqlClientProvider)),
);
final expenseImageProvider = FutureProvider.autoDispose
    .family<ExpenseImage?, ({String id, DateTime time})>((ref, key) async {
      final client = ref.watch(expenseGraphqlClientProvider);
      final result = await client.query(
        QueryOptions(
          document: gql('''
    query ExpenseImage(\$condition: TimelineEventCondition!) {
      allTimelineEvents(first: 1, condition: \$condition) { nodes { $_fields } }
    }
  '''),
          variables: {
            'condition': {
              'id': key.id,
              'time': formatTimelineLocalTimestamp(key.time),
              'eventType': 'image',
              'source': 'expense_app',
            },
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (result.hasException) throw result.exception!;
      final rows =
          result.data?['allTimelineEvents']?['nodes'] as List? ?? const [];
      return rows.isEmpty
          ? null
          : imageFromTimeline(Map<String, dynamic>.from(rows.first as Map));
    });
