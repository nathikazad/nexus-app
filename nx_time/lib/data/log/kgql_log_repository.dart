import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_time/data/log/log_attr_keys.dart';
import 'package:nx_time/data/log/log_mapper.dart';
import 'package:nx_time/domain/log/daily_log.dart';
import 'package:nx_time/domain/log/log_repository.dart';

class KgqlLogRepository implements LogRepository {
  KgqlLogRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadLogSchema,
  }) : _client = client,
       _loadLogSchema = loadLogSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadLogSchema;
  Map<String, dynamic> _logFetchStruct(ModelType schema) {
    final base = buildKgqlStructFromSchema(schema);
    final merged = Map<String, dynamic>.from(base);
    merged['tags'] = true;
    return merged;
  }

  @override
  Future<List<DailyLog>> listForCalendarDay(DateTime dayLocal) async {
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final end = start.add(const Duration(days: 1));

    final schema = await _loadLogSchema();
    final struct = _logFetchStruct(schema);

    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kDailyLogModelTypeName,
        'filters': [
          {
            'key': kDailyLogAttrLoggedAt,
            'op': '>=',
            'value': start.toIso8601String(),
          },
          {
            'key': kDailyLogAttrLoggedAt,
            'op': '<',
            'value': end.toIso8601String(),
          },
        ],
      },
      struct: struct,
    );

    final logs = models.map(dailyLogFromModel).toList()
      ..sort((a, b) {
        final la = a.loggedAt;
        final lb = b.loggedAt;
        if (la == null && lb == null) return a.id.compareTo(b.id);
        if (la == null) return 1;
        if (lb == null) return -1;
        return la.compareTo(lb);
      });
    return logs;
  }

  @override
  Future<DailyLog?> getById(int id) async {
    final schema = await _loadLogSchema();
    final struct = _logFetchStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kDailyLogModelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : dailyLogFromModel(m);
  }

  @override
  Future<int> create({
    required DateTime loggedAt,
    String? entry,
    Map<String, List<String>> tags = const {},
  }) async {
    return setKgqlModel(
      _client,
      setModelRequestForCreateDailyLog(
        loggedAt: loggedAt,
        entry: entry,
        tags: tags,
      ),
    );
  }

  @override
  Future<int> update({
    required int id,
    required DateTime loggedAt,
    String? entry,
    Map<String, List<String>> tags = const {},
  }) async {
    return setKgqlModel(
      _client,
      setModelRequestForUpdateDailyLog(
        id: id,
        loggedAt: loggedAt,
        entry: entry,
        tags: tags,
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await setKgqlModel(_client, setModelRequestForDeleteDailyLog(id));
  }
}
