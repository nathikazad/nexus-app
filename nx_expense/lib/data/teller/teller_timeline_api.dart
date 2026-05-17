import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:nx_expense/data/teller/expense_timeline_api.dart'
    show formatTimelineLocalTimestamp;
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/teller/teller_transaction.dart';

export 'package:nx_expense/domain/teller/teller_link.dart'
    show kTellerTimelineEventType, kTellerTimelineSource;
export 'package:nx_expense/domain/teller/teller_transaction.dart';

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
query TellerTimelineEventsForRange(\$start: Datetime!, \$end: Datetime!, \$first: Int) {
  tellerTimelineEventsForRange(start: \$start, end: \$end, first: \$first)
}
''';

/// True when [row] has at least one linked model of type Expense or Transfer.
bool tellerRowHasExpenseOrTransferLink(TellerTransaction row) {
  for (final m in row.linkedModels) {
    final t = m.modelTypeName;
    if (t == kExpenseModelTypeName || t == kTransferModelTypeName) {
      return true;
    }
  }
  return false;
}

/// Sync marks transactions removed from the Teller API with `deleted: true` in the payload (see `teller.py`).
bool tellerPayloadIsDeleted(Map<String, dynamic> payload) {
  final v = payload['deleted'];
  if (v == true) return true;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
  }
  if (v is num && v != 0) return true;
  return false;
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

List<TellerTransaction> parseTellerTimelineResponse(dynamic data) {
  final root = data as Map<String, dynamic>?;
  final rangeRows = root?['tellerTimelineEventsForRange'];
  final conn = root?['allTimelineEvents'] as Map<String, dynamic>?;
  final nodes = rangeRows is List
      ? rangeRows
      : conn?['nodes'] as List<dynamic>? ?? const [];
  final out = <TellerTransaction>[];
  for (final raw in nodes) {
    if (raw is! Map<String, dynamic>) continue;
    final timeStr = raw['time'] as String?;
    if (timeStr == null) continue;
    final t = DateTime.tryParse(timeStr);
    if (t == null) continue;
    final idRaw = raw['id'];
    final eventId = idRaw == null ? '' : idRaw.toString();
    final payload = _asMap(raw['payload']) ?? {};
    final rangeLinkNodes = raw['linkedModels'];
    final linkConn =
        raw['modelTimelineEventLinksByEventTimeAndEventId']
            as Map<String, dynamic>?;
    final linkNodes = rangeLinkNodes is List
        ? rangeLinkNodes
        : linkConn?['nodes'] as List<dynamic>? ?? const [];
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
      TellerTransaction(
        time: t,
        eventId: eventId,
        payload: payload,
        linkedModels: linked,
      ),
    );
  }
  return out;
}

/// Loads Teller timeline rows for the selected local date range.
Future<List<TellerTransaction>> fetchTellerTimelineEvents(
  GraphQLClient client, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
  int first = 5000,
}) async {
  final exclusiveEnd = DateTime(
    rangeEnd.year,
    rangeEnd.month,
    rangeEnd.day,
  ).add(const Duration(days: 1));
  final result = await client.query(
    QueryOptions(
      document: gql(tellerTimelineEventsQuery),
      variables: {
        'start': formatTimelineLocalTimestamp(rangeStart),
        'end': formatTimelineLocalTimestamp(exclusiveEnd),
        'first': first,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) {
    throw result.exception!;
  }
  return parseTellerTimelineResponse(result.data);
}
