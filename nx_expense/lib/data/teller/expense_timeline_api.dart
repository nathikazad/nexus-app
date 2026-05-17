// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:nx_expense/domain/teller/teller_link.dart';

String _prettyJson(Object? value) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(value);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
String _threeDigits(int value) => value.toString().padLeft(3, '0');

/// Formats timeline timestamps for `timestamp without time zone` columns.
///
/// `timeline_events.time` is a user-local wall-clock timestamp, so GraphQL
/// mutations must preserve the DateTime fields instead of normalizing to UTC.
String formatTimelineLocalTimestamp(DateTime value) {
  final date = [
    value.year.toString().padLeft(4, '0'),
    _twoDigits(value.month),
    _twoDigits(value.day),
  ].join('-');
  final time = [
    _twoDigits(value.hour),
    _twoDigits(value.minute),
    _twoDigits(value.second),
  ].join(':');
  if (value.microsecond != 0) {
    final fraction =
        '${_threeDigits(value.millisecond)}${_threeDigits(value.microsecond)}';
    return '${date}T$time.$fraction';
  }
  if (value.millisecond != 0) {
    return '${date}T$time.${_threeDigits(value.millisecond)}';
  }
  return '${date}T$time';
}

void _printTimelineMutationError({
  required String operationName,
  required String document,
  required Map<String, dynamic> variables,
  required OperationException exception,
}) {
  print('Timeline mutation error: $operationName');
  print('Mutation:');
  print(document);
  print('Variables:');
  print(_prettyJson(variables));
  print('Error: $exception');
  for (final error in exception.graphqlErrors) {
    print('GraphQL error: ${error.message}');
    if (error.extensions != null) {
      print('Extensions: ${_prettyJson(error.extensions)}');
    }
  }
  if (exception.linkException != null) {
    print('Link exception: ${exception.linkException}');
  }
}

const String expenseTimelineLinksQuery = '''
query ExpenseTimelineLinks(\$id: Int!) {
  modelById(id: \$id) {
    id
    modelTimelineEventLinksByModelId {
      nodes {
        id
        eventTime
        eventId
        timelineEventByEventTimeAndEventId {
          time
          id
          eventType
          source
          payload
        }
      }
    }
  }
}
''';

List<TellerExpenseLink> parseExpenseTimelineLinks(dynamic data) {
  final root = data as Map<String, dynamic>?;
  final model = root?['modelById'] as Map<String, dynamic>?;
  if (model == null) return [];
  final conn =
      model['modelTimelineEventLinksByModelId'] as Map<String, dynamic>?;
  final nodes = conn?['nodes'] as List<dynamic>? ?? const [];
  final out = <TellerExpenseLink>[];
  for (final raw in nodes) {
    if (raw is! Map<String, dynamic>) continue;
    final te =
        raw['timelineEventByEventTimeAndEventId'] as Map<String, dynamic>?;
    if (te == null) continue;
    final timeStr = te['time'] as String?;
    if (timeStr == null) continue;
    final t = DateTime.tryParse(timeStr);
    if (t == null) continue;
    final eid = te['id'];
    final eventId = eid == null ? '' : eid.toString();
    final payload = te['payload'];
    final pmap = payload is Map<String, dynamic>
        ? payload
        : payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
    final lid = raw['id'];
    if (lid == null) continue;
    final etRaw = te['eventType'];
    final eventType = etRaw is String ? etRaw : null;
    out.add(
      TellerExpenseLink(
        linkId: lid.toString(),
        eventTime: t,
        eventId: eventId,
        payload: pmap,
        eventType: eventType,
      ),
    );
  }
  return out;
}

Future<List<TellerExpenseLink>> fetchExpenseTimelineLinks(
  GraphQLClient client,
  int modelId,
) async {
  final result = await client.query(
    QueryOptions(
      document: gql(expenseTimelineLinksQuery),
      variables: {'id': modelId},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) {
    throw result.exception!;
  }
  return parseExpenseTimelineLinks(result.data);
}

const String deleteModelTimelineEventLinkByIdMutation = '''
mutation DeleteModelTimelineEventLinkById(\$input: DeleteModelTimelineEventLinkByIdInput!) {
  deleteModelTimelineEventLinkById(input: \$input) {
    clientMutationId
  }
}
''';

Future<void> deleteExpenseTimelineLink(
  GraphQLClient client,
  String linkId,
) async {
  final variables = {
    'input': {'id': linkId},
  };
  final result = await client.mutate(
    MutationOptions(
      document: gql(deleteModelTimelineEventLinkByIdMutation),
      variables: variables,
    ),
  );
  if (result.hasException) {
    _printTimelineMutationError(
      operationName: 'DeleteModelTimelineEventLinkById',
      document: deleteModelTimelineEventLinkByIdMutation,
      variables: variables,
      exception: result.exception!,
    );
    throw result.exception!;
  }
}

const String createModelTimelineEventLinkMutation = '''
mutation CreateModelTimelineEventLink(\$input: CreateModelTimelineEventLinkInput!) {
  createModelTimelineEventLink(input: \$input) {
    modelTimelineEventLink {
      id
    }
  }
}
''';

Future<void> linkExpenseToTimelineEvent(
  GraphQLClient client, {
  required int modelId,
  required DateTime eventTime,
  required String eventId,
}) async {
  final variables = {
    'input': {
      'modelTimelineEventLink': {
        'modelId': modelId,
        'eventTime': formatTimelineLocalTimestamp(eventTime),
        'eventId': eventId,
      },
    },
  };
  final result = await client.mutate(
    MutationOptions(
      document: gql(createModelTimelineEventLinkMutation),
      variables: variables,
    ),
  );
  if (result.hasException) {
    _printTimelineMutationError(
      operationName: 'CreateModelTimelineEventLink',
      document: createModelTimelineEventLinkMutation,
      variables: variables,
      exception: result.exception!,
    );
    throw result.exception!;
  }
}

/// Same junction row as [linkExpenseToTimelineEvent]; use for Transfer (or any model).
Future<void> linkModelToTimelineEvent(
  GraphQLClient client, {
  required int modelId,
  required DateTime eventTime,
  required String eventId,
}) => linkExpenseToTimelineEvent(
  client,
  modelId: modelId,
  eventTime: eventTime,
  eventId: eventId,
);

const String createTimelineEventMutation = '''
mutation CreateTimelineEvent(\$input: CreateTimelineEventInput!) {
  createTimelineEvent(input: \$input) {
    timelineEvent {
      time
      id
      eventType
      source
      payload
    }
  }
}
''';

/// Creates a [timeline_events] row from a Teller-style JSON object, then returns `(time, id)`.
Future<({DateTime time, String eventId})> createTellerTimelineEvent(
  GraphQLClient client, {
  required int userId,
  required Map<String, dynamic> payload,
}) async {
  final dateStr = payload['date']?.toString();
  if (dateStr == null || dateStr.isEmpty) {
    throw ArgumentError(
      'Teller payload must include a "date" field (YYYY-MM-DD).',
    );
  }
  final d = DateTime.tryParse(dateStr);
  if (d == null) {
    throw ArgumentError('Invalid "date": $dateStr');
  }
  final time = DateTime(d.year, d.month, d.day);
  final variables = {
    'input': {
      'timelineEvent': {
        'time': formatTimelineLocalTimestamp(time),
        'userId': userId,
        'eventType': kTellerTimelineEventType,
        'source': kTellerTimelineSource,
        'payload': payload,
      },
    },
  };
  final result = await client.mutate(
    MutationOptions(
      document: gql(createTimelineEventMutation),
      variables: variables,
    ),
  );
  if (result.hasException) {
    _printTimelineMutationError(
      operationName: 'CreateTimelineEvent',
      document: createTimelineEventMutation,
      variables: variables,
      exception: result.exception!,
    );
    throw result.exception!;
  }
  final te =
      (result.data?['createTimelineEvent']
              as Map<String, dynamic>?)?['timelineEvent']
          as Map<String, dynamic>?;
  if (te == null) {
    throw StateError('createTimelineEvent returned no timelineEvent');
  }
  final timeStr = te['time'] as String?;
  final idRaw = te['id'];
  if (timeStr == null || idRaw == null) {
    throw StateError('createTimelineEvent missing time or id');
  }
  final parsed = DateTime.tryParse(timeStr);
  if (parsed == null) {
    throw StateError('Invalid time from server: $timeStr');
  }
  return (time: parsed, eventId: idRaw.toString());
}

const String updateTimelineEventByTimeAndIdMutation = '''
mutation UpdateTimelineEventByTimeAndId(\$input: UpdateTimelineEventByTimeAndIdInput!) {
  updateTimelineEventByTimeAndId(input: \$input) {
    timelineEvent {
      time
      id
      payload
    }
  }
}
''';

Future<void> updateTellerTimelinePayload(
  GraphQLClient client, {
  required DateTime eventTime,
  required String eventId,
  required Map<String, dynamic> payload,
}) async {
  final variables = {
    'input': {
      'time': formatTimelineLocalTimestamp(eventTime),
      'id': eventId,
      'timelineEventPatch': {'payload': payload},
    },
  };
  final result = await client.mutate(
    MutationOptions(
      document: gql(updateTimelineEventByTimeAndIdMutation),
      variables: variables,
    ),
  );
  if (result.hasException) {
    _printTimelineMutationError(
      operationName: 'UpdateTimelineEventByTimeAndId',
      document: updateTimelineEventByTimeAndIdMutation,
      variables: variables,
      exception: result.exception!,
    );
    throw result.exception!;
  }
}

/// Creates a new `teller_transaction` row and links it to [modelId].
Future<void> createTellerTimelineEventAndLinkToExpense(
  GraphQLClient client, {
  required int modelId,
  required int userId,
  required Map<String, dynamic> payload,
}) async {
  final r = await createTellerTimelineEvent(
    client,
    userId: userId,
    payload: payload,
  );
  await linkExpenseToTimelineEvent(
    client,
    modelId: modelId,
    eventTime: r.time,
    eventId: r.eventId,
  );
}

/// Parses and normalizes user-pasted JSON (object or JSON string).
Map<String, dynamic> parseTellerPayloadJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('JSON is empty.');
  }
  final decoded = json.decode(trimmed);
  if (decoded is! Map<String, dynamic>) {
    throw ArgumentError('JSON must be an object.');
  }
  return Map<String, dynamic>.from(decoded);
}
