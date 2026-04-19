import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';

/// Shared mock for repository tests (mirrors `nx_db/test/_support`).
class MockGraphQLClient extends Mock implements GraphQLClient {}

QueryResult okQueryResult(Map<String, dynamic>? data) => QueryResult(
      options: QueryOptions(document: gql('query { __typename }')),
      source: QueryResultSource.network,
      data: data,
    );

void registerGraphqlFallbacks() {
  registerFallbackValue(QueryOptions(document: gql('query { __typename }')));
  registerFallbackValue(MutationOptions(document: gql('mutation { __typename }')));
}
