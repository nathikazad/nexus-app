import 'package:graphql_flutter/graphql_flutter.dart';

/// PostGraphile: `timeline_events` rows for Teller imports (`import_teller_timeline_events.py`).
const String kTellerTimelineEventType = 'teller_transaction';
const String kTellerTimelineSource = 'teller';

/// One-line label for a Teller payload (counterparty or description).
String tellerTransactionTitleLine(Map<String, dynamic> payload) {
  final details = payload['details'];
  if (details is Map) {
    final cp = details['counterparty'];
    if (cp is Map && cp['name'] != null) {
      final s = cp['name'].toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  final desc = (payload['description'] as String?)?.trim() ?? '';
  final first = desc.split('\n').first;
  final cleaned = first.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isNotEmpty) {
    return cleaned.length > 120 ? '${cleaned.substring(0, 120)}…' : cleaned;
  }
  return 'Teller transaction';
}

const String tellerTimelineEventsQuery = '''
query TellerTimelineEvents(\$cond: TimelineEventCondition!) {
  allTimelineEvents(first: 50000, condition: \$cond, orderBy: [TIME_DESC]) {
    nodes {
      time
      id
      payload
      modelTimelineEventLinksByEventTimeAndEventId {
        nodes {
          id
          modelByModelId {
            id
            name
            modelTypeByModelTypeId {
              name
            }
          }
        }
      }
    }
  }
}
''';

class LinkedTellerModel {
  const LinkedTellerModel({
    required this.id,
    required this.name,
    required this.modelTypeName,
    this.linkId,
  });

  final int id;
  final String name;
  final String modelTypeName;

  /// `model_timeline_event_links.id` for [deleteExpenseTimelineLink].
  final String? linkId;
}

class TellerTransactionRow {
  const TellerTransactionRow({
    required this.time,
    required this.eventId,
    required this.payload,
    required this.linkedModels,
  });

  final DateTime time;
  final String eventId;
  final Map<String, dynamic> payload;
  final List<LinkedTellerModel> linkedModels;
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

List<TellerTransactionRow> parseTellerTimelineResponse(dynamic data) {
  final root = data as Map<String, dynamic>?;
  final conn = root?['allTimelineEvents'] as Map<String, dynamic>?;
  final nodes = conn?['nodes'] as List<dynamic>? ?? const [];
  final out = <TellerTransactionRow>[];
  for (final raw in nodes) {
    if (raw is! Map<String, dynamic>) continue;
    final timeStr = raw['time'] as String?;
    if (timeStr == null) continue;
    final t = DateTime.tryParse(timeStr);
    if (t == null) continue;
    final idRaw = raw['id'];
    final eventId = idRaw == null ? '' : idRaw.toString();
    final payload = _asMap(raw['payload']) ?? {};
    final linkConn = raw['modelTimelineEventLinksByEventTimeAndEventId'] as Map<String, dynamic>?;
    final linkNodes = linkConn?['nodes'] as List<dynamic>? ?? const [];
    final linked = <LinkedTellerModel>[];
    for (final ln in linkNodes) {
      if (ln is! Map<String, dynamic>) continue;
      final m = ln['modelByModelId'] as Map<String, dynamic>?;
      if (m == null) continue;
      final linkId = ln['id']?.toString();
      final mid = m['id'];
      final id = mid is int ? mid : int.tryParse('$mid');
      if (id == null) continue;
      final name = (m['name'] as String?) ?? '';
      final mt = m['modelTypeByModelTypeId'] as Map<String, dynamic>?;
      final typeName = (mt?['name'] as String?) ?? '';
      linked.add(
        LinkedTellerModel(
          id: id,
          name: name,
          modelTypeName: typeName,
          linkId: linkId,
        ),
      );
    }
    out.add(
      TellerTransactionRow(
        time: t,
        eventId: eventId,
        payload: payload,
        linkedModels: linked,
      ),
    );
  }
  return out;
}

/// Loads all Teller timeline rows for the current user (RLS via [GraphQLClient] headers).
Future<List<TellerTransactionRow>> fetchTellerTimelineEvents(GraphQLClient client) async {
  final result = await client.query(
    QueryOptions(
      document: gql(tellerTimelineEventsQuery),
      variables: {
        'cond': {
          'eventType': kTellerTimelineEventType,
          'source': kTellerTimelineSource,
        },
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) {
    throw result.exception!;
  }
  return parseTellerTimelineResponse(result.data);
}
