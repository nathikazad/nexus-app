import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/nx_db.dart' as nx;
import '../../domain/logs/log_records.dart';
import '../../domain/logs/log_repository.dart';
import 'log_record_mappers.dart';

final logRepositoryProvider = Provider<LogRepository>(
    (ref) => KgqlLogRepository(ref.watch(nx.graphqlClientProvider)));

/// The selected session supplies the client; no process-wide client is cached.
class KgqlLogRepository implements LogRepository {
  KgqlLogRepository(this.client);
  final GraphQLClient client;

  @override
  Future<List<NexusLogRow>> logsForDay(DateTime date) async =>
      (await nx.fetchLogsForDay(client, date: date))
          .map(nexusLogRowFromNx)
          .toList();
  @override
  Future<List<DbChangeOperation>> operationsForDay(DateTime date) async =>
      (await nx.fetchChangeOperationsForDay(client, date: date))
          .map(dbChangeOperationFromNx)
          .toList();
  @override
  Future<DbChangeOperation?> operation(String id) async {
    final row = await nx.fetchChangeOperation(client, operationId: id);
    return row == null ? null : dbChangeOperationFromNx(row);
  }

  @override
  Future<List<DbChangeEvent>> events(String operationId) async =>
      (await nx.fetchChangeEvents(client, operationId: operationId))
          .map(dbChangeEventFromNx)
          .toList();
  @override
  Future<DbChangeMetadata> metadata() async =>
      dbChangeMetadataFromNx(await nx.fetchDbChangeMetadata(client));
  @override
  Future<void> updatePayload(String id, Map<String, dynamic> payload) async {
    // Updates require the exact timestamp from the stored row, not UI precision.
    final row = await nx.fetchLogById(client, id: id);
    if (row == null) throw StateError('Log row $id not found.');
    final time = row.time;
    if (time == null) throw StateError('Log row $id has no exact update time.');
    await nx.updateLogPayload(client, time: time, id: row.id, payload: payload);
  }
}
