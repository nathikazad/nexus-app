import 'package:nx_people/data/sync/people_data_repository.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/domain/log/daily_log.dart';
import 'package:nx_people/domain/log/log_repository.dart';

const kDailyLogModelTypeName = 'Daily Log';
const kDailyLogEntryAttribute = 'entry';
const kDailyLogImageUrlAttribute = 'image_url';
const kDailyLogLoggedAtAttribute = 'logged_at';

class KgqlLogRepository implements LogRepository {
  KgqlLogRepository({required GraphQLClient client, this.data})
    : _client = client;

  final PeopleDataRepository? data;
  final GraphQLClient _client;

  @override
  Future<List<DailyLog>> listForCalendarDay(DateTime dayLocal) async {
    final models = data != null
        ? await data!.models(kDailyLogModelTypeName)
        : await fetchKgqlModels(
            _client,
            filter: dailyLogDayFilter(dayLocal),
            struct: const <String, dynamic>{
              'id': true,
              'name': true,
              'model_type_id': true,
              kDailyLogLoggedAtAttribute: true,
              kDailyLogEntryAttribute: true,
              kDailyLogImageUrlAttribute: true,
            },
          );
    final logs = <DailyLog>[
      for (final model in models)
        if (model.attrDateTime(kDailyLogLoggedAtAttribute) case final loggedAt?)
          DailyLog(
            id: model.id,
            loggedAt: loggedAt,
            entry: model.attrString(kDailyLogEntryAttribute),
            imageUrl: model.attrString(kDailyLogImageUrlAttribute),
          ),
    ];
    logs.removeWhere(
      (log) =>
          log.loggedAt.year != dayLocal.year ||
          log.loggedAt.month != dayLocal.month ||
          log.loggedAt.day != dayLocal.day,
    );
    logs.sort((left, right) => right.loggedAt.compareTo(left.loggedAt));
    return logs;
  }

  @override
  Future<int> create(DailyLogDraft draft) {
    return data?.set(dailyLogCreateRequest(draft)) ??
        setKgqlModel(_client, dailyLogCreateRequest(draft));
  }
}

Map<String, dynamic> dailyLogDayFilter(DateTime dayLocal) {
  final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final end = start.add(const Duration(days: 1));
  return <String, dynamic>{
    'model_type': kDailyLogModelTypeName,
    'filters': <Map<String, dynamic>>[
      <String, dynamic>{
        'key': kDailyLogLoggedAtAttribute,
        'op': '>=',
        'value': start.toIso8601String(),
      },
      <String, dynamic>{
        'key': kDailyLogLoggedAtAttribute,
        'op': '<',
        'value': end.toIso8601String(),
      },
    ],
  };
}

SetModelRequest dailyLogCreateRequest(DailyLogDraft draft) {
  if (!draft.hasContent) {
    throw ArgumentError('A log needs text, an image, or both.');
  }
  final entry = draft.entry?.trim();
  final imageUrl = draft.imageUrl?.trim();
  return setKgqlCreate(
    modelType: kDailyLogModelTypeName,
    name: _logName(draft.loggedAt),
    attributes: <SetModelAttribute>[
      SetModelAttribute(
        key: kDailyLogLoggedAtAttribute,
        value: draft.loggedAt.toIso8601String(),
      ),
      if (entry != null && entry.isNotEmpty)
        SetModelAttribute(key: kDailyLogEntryAttribute, value: entry),
      if (imageUrl != null && imageUrl.isNotEmpty)
        SetModelAttribute(key: kDailyLogImageUrlAttribute, value: imageUrl),
    ],
  );
}

String _logName(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return 'Log ${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
