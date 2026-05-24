import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/features/logs/log_pipeline_mappers.dart';
import 'package:nexus_voice_assistant/features/logs/log_pipeline_models.dart';
import 'package:nx_db/nx_db.dart';

enum DbChangeFilter {
  all('All DB changes'),
  timeline('Timeline changes'),
  transcript('Transcript changes'),
  model('Model changes');

  const DbChangeFilter(this.label);
  final String label;
}

class LogsViewModeController extends Notifier<LogsViewMode> {
  @override
  LogsViewMode build() => LogsViewMode.audioPipeline;

  void setMode(LogsViewMode mode) {
    state = mode;
  }
}

final logsViewModeProvider =
    NotifierProvider<LogsViewModeController, LogsViewMode>(
  LogsViewModeController.new,
  name: 'logsViewModeProvider',
);

class LogsSelectedDateController extends Notifier<DateTime> {
  @override
  DateTime build() => normalizeLogDate(DateTime.now());

  void setDate(DateTime date) {
    state = normalizeLogDate(date);
  }
}

final logsSelectedDateProvider =
    NotifierProvider<LogsSelectedDateController, DateTime>(
  LogsSelectedDateController.new,
  name: 'logsSelectedDateProvider',
);

class DbChangeFilterController extends Notifier<DbChangeFilter> {
  @override
  DbChangeFilter build() => DbChangeFilter.model;

  void setFilter(DbChangeFilter filter) {
    state = filter;
  }
}

final dbChangeFilterProvider =
    NotifierProvider<DbChangeFilterController, DbChangeFilter>(
  DbChangeFilterController.new,
  name: 'dbChangeFilterProvider',
);

final logsForDayProvider =
    FutureProvider.family<List<NexusLogRow>, DateTime>((ref, date) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchLogsForDay(client, date: normalizeLogDate(date));
}, name: 'logsForDayProvider');

final audioPipelineTurnsProvider =
    FutureProvider.family<List<AudioPipelineTurn>, DateTime>((ref, date) async {
  final rows = await ref.watch(logsForDayProvider(date).future);
  return buildAudioPipelineTurns(rows);
}, name: 'audioPipelineTurnsProvider');

final agentPipelineRunsProvider =
    FutureProvider.family<List<AgentPipelineRun>, DateTime>((ref, date) async {
  final rows = await ref.watch(logsForDayProvider(date).future);
  return buildAgentRuns(rows);
}, name: 'agentPipelineRunsProvider');

final dbChangeOperationsProvider =
    FutureProvider.family<List<DbChangeOperation>, DateTime>((ref, date) async {
  final client = ref.watch(graphqlClientProvider);
  final operations =
      await fetchChangeOperationsForDay(client, date: normalizeLogDate(date));
  operations.sort((a, b) {
    final time = (b.createdAt?.millisecondsSinceEpoch ?? 0)
        .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0);
    if (time != 0) return time;
    return b.id.compareTo(a.id);
  });
  return operations;
}, name: 'dbChangeOperationsProvider');

final dbChangeOperationsWithEventsProvider =
    FutureProvider.family<List<DbChangeOperationWithEvents>, DateTime>(
        (ref, date) async {
  final operations = await ref.watch(dbChangeOperationsProvider(date).future);
  final metadata = await ref.watch(dbChangeMetadataProvider.future);
  final values = await Future.wait(
    operations.map((operation) async {
      final events =
          await ref.watch(dbChangeEventsProvider(operation.id).future);
      return DbChangeOperationWithEvents(
        operation: operation,
        events: events,
        metadata: metadata,
      );
    }),
  );
  return values;
}, name: 'dbChangeOperationsWithEventsProvider');

final filteredDbChangeOperationsProvider = Provider.family<
    AsyncValue<List<DbChangeOperation>>,
    DbChangeOperationsFilterKey>((ref, key) {
  final state = ref.watch(dbChangeOperationsWithEventsProvider(key.date));
  return state.whenData((values) {
    if (key.filter == DbChangeFilter.all) {
      return values.map((value) => value.operation).toList();
    }
    return values
        .where((value) =>
            _operationMatchesFilter(value.events, key.filter, value.metadata))
        .map((value) => value.operation)
        .toList();
  });
}, name: 'filteredDbChangeOperationsProvider');

final dbChangeMetadataProvider = FutureProvider<DbChangeMetadata>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchDbChangeMetadata(client);
}, name: 'dbChangeMetadataProvider');

final dbChangeEventsProvider =
    FutureProvider.family<List<DbChangeEvent>, String>(
        (ref, operationId) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchChangeEvents(client, operationId: operationId);
}, name: 'dbChangeEventsProvider');

final dbChangeDetailProvider =
    FutureProvider.family<DbChangeDetail, DbChangeDetailKey>((ref, key) async {
  final operations =
      await ref.watch(dbChangeOperationsProvider(key.date).future);
  final operation = operations.firstWhere(
    (item) => item.id == key.operationId,
    orElse: () =>
        throw StateError('Change operation ${key.operationId} not found'),
  );
  final events =
      await ref.watch(dbChangeEventsProvider(key.operationId).future);
  final metadata = await ref.watch(dbChangeMetadataProvider.future);
  return DbChangeDetail(
      operation: operation, events: events, metadata: metadata);
}, name: 'dbChangeDetailProvider');

class DbChangeDetailKey {
  const DbChangeDetailKey({required this.date, required this.operationId});

  final DateTime date;
  final String operationId;

  @override
  bool operator ==(Object other) {
    return other is DbChangeDetailKey &&
        _dayKey(other.date) == _dayKey(date) &&
        other.operationId == operationId;
  }

  @override
  int get hashCode => Object.hash(_dayKey(date), operationId);
}

class DbChangeOperationWithEvents {
  const DbChangeOperationWithEvents({
    required this.operation,
    required this.events,
    required this.metadata,
  });

  final DbChangeOperation operation;
  final List<DbChangeEvent> events;
  final DbChangeMetadata metadata;
}

class DbChangeOperationsFilterKey {
  const DbChangeOperationsFilterKey({
    required this.date,
    required this.filter,
  });

  final DateTime date;
  final DbChangeFilter filter;

  @override
  bool operator ==(Object other) {
    return other is DbChangeOperationsFilterKey &&
        _dayKey(other.date) == _dayKey(date) &&
        other.filter == filter;
  }

  @override
  int get hashCode => Object.hash(_dayKey(date), filter);
}

String formatLogDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime parseLogDate(String? value) {
  if (value == null || value.isEmpty) return normalizeLogDate(DateTime.now());
  return normalizeLogDate(DateTime.tryParse(value) ?? DateTime.now());
}

String _dayKey(DateTime date) => formatLogDate(date);

DateTime normalizeLogDate(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _operationMatchesFilter(
  List<DbChangeEvent> events,
  DbChangeFilter filter,
  DbChangeMetadata metadata,
) {
  return switch (filter) {
    DbChangeFilter.all => true,
    DbChangeFilter.timeline => events.any(_isTimelineChangeEvent),
    DbChangeFilter.transcript =>
      events.any((event) => _isTranscriptChangeEvent(event, metadata)),
    DbChangeFilter.model => events.any(_isModelChangeEvent) &&
        !_isTranscriptChangeOperation(events, metadata),
  };
}

bool _isTimelineChangeEvent(DbChangeEvent event) {
  final row = event.afterRow.isNotEmpty ? event.afterRow : event.beforeRow;
  return event.tableName == 'timeline_events' ||
      event.tableName.startsWith('_hyper_') ||
      (row.containsKey('event_type') &&
          row.containsKey('payload') &&
          row.containsKey('time'));
}

bool _isModelChangeEvent(DbChangeEvent event) {
  return const {
    'models',
    'attributes',
    'relations',
    'relation_attributes',
    'model_types',
    'attribute_definitions',
    'relationship_types',
    'relation_attribute_definitions',
  }.contains(event.tableName);
}

bool _isTranscriptChangeEvent(DbChangeEvent event, DbChangeMetadata metadata) {
  final row = event.afterRow.isNotEmpty ? event.afterRow : event.beforeRow;
  if (event.tableName == 'models') {
    return metadata.modelTypeName(row['model_type_id']) == 'Transcript';
  }
  if (event.tableName != 'attributes') return false;
  final attrDefId = int.tryParse('${row['attribute_definition_id'] ?? ''}');
  if (attrDefId == null) return false;
  final attr = metadata.attributeDefinitions[attrDefId];
  if (attr == null || attr['key'] != 'messages') return false;
  final modelTypeId = attr['modelTypeId'] ?? attr['model_type_id'];
  return metadata.modelTypeName(modelTypeId) == 'Transcript';
}

bool _isTranscriptChangeOperation(
  List<DbChangeEvent> events,
  DbChangeMetadata metadata,
) {
  return events.any((event) => _isTranscriptChangeEvent(event, metadata));
}
