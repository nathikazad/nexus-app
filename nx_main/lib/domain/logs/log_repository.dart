import 'log_records.dart';

abstract interface class LogRepository {
  Future<List<NexusLogRow>> logsForDay(DateTime date);
  Future<List<DbChangeOperation>> operationsForDay(DateTime date);
  Future<DbChangeOperation?> operation(String id);
  Future<List<DbChangeEvent>> events(String operationId);
  Future<DbChangeMetadata> metadata();
  Future<void> updatePayload(String id, Map<String, dynamic> payload);
}
