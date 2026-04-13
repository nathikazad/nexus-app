import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';

import 'teller_timeline_api.dart';

/// PostGraphile `timeline_events.event_type` for bill photos from the expense app.
const String kExpenseImageTimelineEventType = 'image';

/// One `model_timeline_event_links` row with the joined timeline payload (Teller or image).
class ExpenseTellerLink {
  const ExpenseTellerLink({
    required this.linkId,
    required this.eventTime,
    required this.eventId,
    required this.payload,
    this.eventType,
  });

  final String linkId;
  final DateTime eventTime;
  final String eventId;
  final Map<String, dynamic> payload;

  /// From `timeline_events.event_type` when present; null treated as Teller for older rows.
  final String? eventType;

  /// Rows shown in the Teller UI (legacy rows without [eventType] count as Teller).
  bool get isTellerTimelineEvent =>
      eventType == null || eventType == kTellerTimelineEventType;

  /// Bill photo rows (`event_type == image`).
  bool get isBillImageEvent => eventType == kExpenseImageTimelineEventType;

  /// Row for [TellerTransactionDetailScreen] (linked models not loaded from this query).
  TellerTransactionRow toTellerTransactionRow() {
    return TellerTransactionRow(
      time: eventTime,
      eventId: eventId,
      payload: payload,
      linkedModels: const [],
    );
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

List<ExpenseTellerLink> parseExpenseTimelineLinks(dynamic data) {
  final root = data as Map<String, dynamic>?;
  final model = root?['modelById'] as Map<String, dynamic>?;
  if (model == null) return [];
  final conn = model['modelTimelineEventLinksByModelId'] as Map<String, dynamic>?;
  final nodes = conn?['nodes'] as List<dynamic>? ?? const [];
  final out = <ExpenseTellerLink>[];
  for (final raw in nodes) {
    if (raw is! Map<String, dynamic>) continue;
    final te = raw['timelineEventByEventTimeAndEventId'] as Map<String, dynamic>?;
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
      ExpenseTellerLink(
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

Future<List<ExpenseTellerLink>> fetchExpenseTimelineLinks(
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

Future<void> deleteExpenseTimelineLink(GraphQLClient client, String linkId) async {
  final result = await client.mutate(
    MutationOptions(
      document: gql(deleteModelTimelineEventLinkByIdMutation),
      variables: {
        'input': {'id': linkId},
      },
    ),
  );
  if (result.hasException) {
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
  final result = await client.mutate(
    MutationOptions(
      document: gql(createModelTimelineEventLinkMutation),
      variables: {
        'input': {
          'modelTimelineEventLink': {
            'modelId': modelId,
            'eventTime': eventTime.toUtc().toIso8601String(),
            'eventId': eventId,
          },
        },
      },
    ),
  );
  if (result.hasException) {
    throw result.exception!;
  }
}

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
    throw ArgumentError('Teller payload must include a "date" field (YYYY-MM-DD).');
  }
  final d = DateTime.tryParse(dateStr);
  if (d == null) {
    throw ArgumentError('Invalid "date": $dateStr');
  }
  final timeUtc = DateTime.utc(d.year, d.month, d.day);
  final result = await client.mutate(
    MutationOptions(
      document: gql(createTimelineEventMutation),
      variables: {
        'input': {
          'timelineEvent': {
            'time': timeUtc.toIso8601String(),
            'userId': userId,
            'eventType': kTellerTimelineEventType,
            'source': kTellerTimelineSource,
            'payload': payload,
          },
        },
      },
    ),
  );
  if (result.hasException) {
    throw result.exception!;
  }
  final te = (result.data?['createTimelineEvent'] as Map<String, dynamic>?)?['timelineEvent']
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
  final result = await client.mutate(
    MutationOptions(
      document: gql(updateTimelineEventByTimeAndIdMutation),
      variables: {
        'input': {
          'time': eventTime.toUtc().toIso8601String(),
          'id': eventId,
          'timelineEventPatch': {
            'payload': payload,
          },
        },
      },
    ),
  );
  if (result.hasException) {
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
