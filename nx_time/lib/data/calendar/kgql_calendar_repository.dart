import 'dart:convert';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';

class KgqlCalendarRepository {
  KgqlCalendarRepository(this.client, {required this.domainId});
  final GraphQLClient client;
  final int domainId;
  Future<CalendarFeed> load(
    DateTime from,
    DateTime until, {
    bool actualHistory = false,
  }) async {
    final result = await client.query(
      QueryOptions(
        document: gql(r'''
      query Calendar($from:Datetime!,$until:Datetime!,$domain:Int!,$actual:Boolean!) {
        getKgqlCalendar(rangeStart:$from,rangeEndExcl:$until,domainId:$domain,actualHistory:$actual)
      }
    '''),
        variables: {
          'from': from.toIso8601String(),
          'until': until.toIso8601String(),
          'domain': domainId,
          'actual': actualHistory,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (result.hasException) throw result.exception!;
    final raw = result.data?['getKgqlCalendar'];
    if (raw == null) throw StateError('Calendar returned no data');
    return CalendarFeed.fromJson(
      Map<String, dynamic>.from((raw is String ? jsonDecode(raw) : raw) as Map),
    );
  }

  Future<int> save({
    int? id,
    String? modelType,
    String? name,
    String? description,
    Map<String, dynamic> attributes = const {},
    List<ModelRelation>? relations,
  }) => setKgqlModel(
    client,
    SetModelRequest(
      id: id,
      modelType: modelType,
      name: name,
      description: description,
      attributes: [
        for (final e in attributes.entries)
          SetModelAttribute(
            key: e.key,
            value: e.value,
            delete: e.value == null,
          ),
      ],
      relations: relations,
    ),
    domainId: domainId,
  );

  Future<List<Model>> _models(
    Map<String, dynamic> filter,
    Map<String, dynamic> struct,
  ) async {
    final response = await client.query(
      QueryOptions(
        document: gql(
          r"query CalendarModels($filter:JSON!,$struct:JSON!,$domain:Int!){getKgqlModels(filter:$filter,struct:$struct,domainId:$domain)}",
        ),
        variables: {'filter': filter, 'struct': struct, 'domain': domainId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (response.hasException) throw response.exception!;
    return parseKgqlModelsResult(response.data?['getKgqlModels']);
  }

  Future<List<Model>> choices(String type) => _models(
    {'model_type': type},
    {
      'id': true,
      'name': true,
      'description': true,
      if (type == 'Person') 'birthday': true,
    },
  );

  Future<int> planAttendance(CalendarEntry event) async {
    // Fresh read before deciding to create; stale calendar snapshots aren't authority.
    final models = await _models(
      {
        'model_type': 'Goto',
        'relation_filters': [
          {
            'model_type': 'Event',
            'filters': [
              {'key': 'id', 'op': '=', 'value': event.id},
            ],
          },
        ],
      },
      {
        'id': true,
        'name': true,
        'planning_status': true,
        'start_time': true,
        'Event': {'id': true},
      },
    );
    final matches = models
        .where(
          (m) => (m.relations?['Event'] ?? []).any((e) => e.id == event.id),
        )
        .toList();
    if (matches.any(
      (m) =>
          m.attrDateTime('start_time') != null ||
          m.attrString('planning_status') == 'attended',
    )) {
      throw StateError(
        'Attendance is already recorded. Open it to edit instead.',
      );
    }
    if (matches.length > 1) {
      throw StateError(
        'Multiple attendance records exist. Open the intended attendance record.',
      );
    }
    return save(
      id: matches.isEmpty ? null : matches.single.id,
      modelType: matches.isEmpty ? 'Goto' : null,
      name: matches.isEmpty ? 'Attend ${event.name}' : null,
      attributes: {
        'planning_status': 'planned',
        'scheduled_start_time': event.time('start_time')?.toIso8601String(),
        'scheduled_end_time': event.time('end_time')?.toIso8601String(),
      },
      relations: matches.isEmpty
          ? [
              ModelRelation(
                modelType: 'Event',
                relationName: 'to_event',
                link: [event.id],
              ),
            ]
          : null,
    );
  }
}
