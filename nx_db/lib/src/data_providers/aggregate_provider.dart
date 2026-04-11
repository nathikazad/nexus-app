import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

const String getKgqlAggregateQuery = '''
query GetKgqlAggregate(\$filterkgql: JSON, \$aggregate: JSON) {
  getKgqlAggregate(filterkgql: \$filterkgql, aggregate: \$aggregate)
}
''';

/// Calls `get_kgql_aggregate` via GraphQL. [filterKgql] is the filter DSL (e.g. `model_type`).
///
/// The result is parsed to a JSON object (handles string or map responses from PostGraphile).
Future<Map<String, dynamic>> getKgqlAggregate(
  GraphQLClient client,
  Map<String, dynamic> filterKgql,
  Map<String, dynamic> aggregate,
) async {
  final result = await client.query(
    QueryOptions(
      document: gql(getKgqlAggregateQuery),
      variables: {
        'filterkgql': filterKgql,
        'aggregate': aggregate,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  return parseKgqlAggregateResult(result.data?['getKgqlAggregate']);
}

/// Parses PostGraphile `getKgqlAggregate` payload (string or map).
@visibleForTesting
Map<String, dynamic> parseKgqlAggregateResult(dynamic raw) {
  if (raw == null) {
    return {};
  }
  if (raw is List) {
    return {'grouped': raw};
  }
  if (raw is String) {
    final decoded = json.decode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is List) {
      return {'grouped': decoded};
    }
    throw FormatException('getKgqlAggregate: expected JSON object or array, got $decoded');
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  throw FormatException('getKgqlAggregate: unexpected type ${raw.runtimeType}');
}
