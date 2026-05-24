import 'package:graphql_flutter/graphql_flutter.dart';

import '../core/json/payload_unwrap.dart';
import 'documents/logs.graphql.dart';
import 'log_models.dart';

DateTime startOfLocalDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime endOfLocalDay(DateTime date) =>
    startOfLocalDay(date).add(const Duration(days: 1));

Map<String, dynamic> dayVariables(DateTime date, {int first = 2000}) {
  return {
    'start': startOfLocalDay(date).toUtc().toIso8601String(),
    'end': endOfLocalDay(date).toUtc().toIso8601String(),
    'first': first,
  };
}

Future<List<NexusLogRow>> fetchLogsForDay(
  GraphQLClient client, {
  required DateTime date,
  int first = 2000,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(logsForDayQuery),
      variables: dayVariables(date, first: first),
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) throw result.exception!;

  return unwrapJsonList(result.data?['logsForDay'])
      .whereType<Map>()
      .map((row) => NexusLogRow.fromJson(Map<String, dynamic>.from(row)))
      .toList();
}

Future<List<DbChangeOperation>> fetchChangeOperationsForDay(
  GraphQLClient client, {
  required DateTime date,
  int first = 2000,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(changeOperationsForDayQuery),
      variables: dayVariables(date, first: first),
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) throw result.exception!;

  return unwrapJsonList(result.data?['changeOperationsForDay'])
      .whereType<Map>()
      .map((row) => DbChangeOperation.fromJson(Map<String, dynamic>.from(row)))
      .toList();
}

Future<List<DbChangeEvent>> fetchChangeEvents(
  GraphQLClient client, {
  required String operationId,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(changeEventsQuery),
      variables: {'operationId': operationId},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) throw result.exception!;

  return nodeList(result.data?['allChangeEvents'])
      .map(DbChangeEvent.fromJson)
      .toList();
}

Future<DbChangeMetadata> fetchDbChangeMetadata(GraphQLClient client) async {
  final result = await client.query(
    QueryOptions(
      document: gql(dbChangeMetadataQuery),
      fetchPolicy: FetchPolicy.cacheFirst,
    ),
  );

  if (result.hasException) throw result.exception!;

  return DbChangeMetadata.fromJson(result.data ?? const {});
}
