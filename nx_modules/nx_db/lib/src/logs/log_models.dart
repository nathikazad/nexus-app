class NexusLogRow {
  const NexusLogRow({
    required this.id,
    required this.time,
    required this.receivedAt,
    required this.originKind,
    required this.origin,
    required this.severity,
    required this.message,
    required this.userId,
    required this.deviceId,
    required this.sessionId,
    required this.traceId,
    required this.eventName,
    required this.category,
    required this.payload,
  });

  final String id;
  final DateTime? time;
  final DateTime? receivedAt;
  final String originKind;
  final String origin;
  final String severity;
  final String message;
  final String userId;
  final String deviceId;
  final String sessionId;
  final String traceId;
  final String eventName;
  final String category;
  final Map<String, dynamic> payload;

  factory NexusLogRow.fromJson(Map<String, dynamic> json) {
    return NexusLogRow(
      id: stringValue(json['id']),
      time: dateValue(json['time']),
      receivedAt: dateValue(json['receivedAt'] ?? json['received_at']),
      originKind: stringValue(json['originKind'] ?? json['origin_kind']),
      origin: stringValue(json['origin']),
      severity: stringValue(json['severity']),
      message: stringValue(json['message']),
      userId: stringValue(json['userId'] ?? json['user_id']),
      deviceId: stringValue(json['deviceId'] ?? json['device_id']),
      sessionId: stringValue(json['sessionId'] ?? json['session_id']),
      traceId: stringValue(json['traceId'] ?? json['trace_id']),
      eventName: stringValue(json['eventName'] ?? json['event_name']),
      category: stringValue(json['category']),
      payload: mapValue(json['payload']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time?.toIso8601String(),
        'receivedAt': receivedAt?.toIso8601String(),
        'originKind': originKind,
        'origin': origin,
        'severity': severity,
        'message': message,
        'userId': userId,
        'deviceId': deviceId,
        'sessionId': sessionId,
        'traceId': traceId,
        'eventName': eventName,
        'category': category,
        'payload': payload,
      };
}

class DbChangeOperation {
  const DbChangeOperation({
    required this.id,
    required this.createdAt,
    required this.sourceKind,
    required this.sourceId,
    required this.sourceLabel,
    required this.userId,
    required this.domainId,
    required this.txid,
    required this.reversalOfOperationId,
    required this.reversedByOperationId,
    required this.reversedAt,
  });

  final String id;
  final DateTime? createdAt;
  final String sourceKind;
  final String sourceId;
  final String sourceLabel;
  final String userId;
  final String domainId;
  final String txid;
  final String reversalOfOperationId;
  final String reversedByOperationId;
  final DateTime? reversedAt;

  factory DbChangeOperation.fromJson(Map<String, dynamic> json) {
    return DbChangeOperation(
      id: stringValue(json['id']),
      createdAt: dateValue(json['createdAt'] ?? json['created_at']),
      sourceKind: stringValue(json['sourceKind'] ?? json['source_kind']),
      sourceId: stringValue(json['sourceId'] ?? json['source_id']),
      sourceLabel: stringValue(json['sourceLabel'] ?? json['source_label']),
      userId: stringValue(json['userId'] ?? json['user_id']),
      domainId: stringValue(json['domainId'] ?? json['domain_id']),
      txid: stringValue(json['txid']),
      reversalOfOperationId: stringValue(
        json['reversalOfOperationId'] ?? json['reversal_of_operation_id'],
      ),
      reversedByOperationId: stringValue(
        json['reversedByOperationId'] ?? json['reversed_by_operation_id'],
      ),
      reversedAt: dateValue(json['reversedAt'] ?? json['reversed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt?.toIso8601String(),
        'sourceKind': sourceKind,
        'sourceId': sourceId,
        'sourceLabel': sourceLabel,
        'userId': userId,
        'domainId': domainId,
        'txid': txid,
        'reversalOfOperationId': reversalOfOperationId,
        'reversedByOperationId': reversedByOperationId,
        'reversedAt': reversedAt?.toIso8601String(),
      };
}

class DbChangeEvent {
  const DbChangeEvent({
    required this.id,
    required this.operationId,
    required this.occurredAt,
    required this.tableName,
    required this.op,
    required this.rowPk,
    required this.beforeRow,
    required this.afterRow,
  });

  final String id;
  final String operationId;
  final DateTime? occurredAt;
  final String tableName;
  final String op;
  final Map<String, dynamic> rowPk;
  final Map<String, dynamic> beforeRow;
  final Map<String, dynamic> afterRow;

  factory DbChangeEvent.fromJson(Map<String, dynamic> json) {
    return DbChangeEvent(
      id: stringValue(json['id']),
      operationId: stringValue(json['operationId'] ?? json['operation_id']),
      occurredAt: dateValue(json['occurredAt'] ?? json['occurred_at']),
      tableName: stringValue(json['tableName'] ?? json['table_name']),
      op: stringValue(json['op']),
      rowPk: mapValue(json['rowPk'] ?? json['row_pk']),
      beforeRow: mapValue(json['beforeRow'] ?? json['before_row']),
      afterRow: mapValue(json['afterRow'] ?? json['after_row']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'operationId': operationId,
        'occurredAt': occurredAt?.toIso8601String(),
        'tableName': tableName,
        'op': op,
        'rowPk': rowPk,
        'beforeRow': beforeRow,
        'afterRow': afterRow,
      };
}

class DbChangeMetadata {
  const DbChangeMetadata({
    required this.modelTypes,
    required this.attributeDefinitions,
    required this.relationshipTypes,
    required this.relationAttributeDefinitions,
  });

  final Map<int, Map<String, dynamic>> modelTypes;
  final Map<int, Map<String, dynamic>> attributeDefinitions;
  final Map<int, Map<String, dynamic>> relationshipTypes;
  final Map<int, Map<String, dynamic>> relationAttributeDefinitions;

  factory DbChangeMetadata.fromJson(Map<String, dynamic> json) {
    return DbChangeMetadata(
      modelTypes: nodesById(json['allModelTypes']),
      attributeDefinitions: nodesById(json['allAttributeDefinitions']),
      relationshipTypes: nodesById(json['allRelationshipTypes']),
      relationAttributeDefinitions:
          nodesById(json['allRelationAttributeDefinitions']),
    );
  }

  String modelTypeName(Object? id) {
    final key = int.tryParse(stringValue(id));
    if (key == null) return 'model_type ${stringValue(id).isEmpty ? '-' : id}';
    return stringValue(modelTypes[key]?['name']).isEmpty
        ? 'model_type $id'
        : stringValue(modelTypes[key]?['name']);
  }

  String attributeKey(Object? id) {
    final key = int.tryParse(stringValue(id));
    if (key == null) return 'attribute ${stringValue(id).isEmpty ? '-' : id}';
    return stringValue(attributeDefinitions[key]?['key']).isEmpty
        ? 'attribute $id'
        : stringValue(attributeDefinitions[key]?['key']);
  }
}

String stringValue(Object? value) => value == null ? '' : value.toString();

DateTime? dateValue(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> mapValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> nodeList(Object? connection) {
  final map = mapValue(connection);
  final nodes = map['nodes'];
  if (nodes is List) {
    return nodes
        .whereType<Map>()
        .map((node) => Map<String, dynamic>.from(node))
        .toList();
  }
  return const [];
}

Map<int, Map<String, dynamic>> nodesById(Object? connection) {
  return {
    for (final row in nodeList(connection))
      if (int.tryParse(stringValue(row['id'])) != null)
        int.parse(stringValue(row['id'])): row,
  };
}
