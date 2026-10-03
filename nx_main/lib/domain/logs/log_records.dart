/// App-owned log read models. Database DTOs are mapped in data/logs.
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

  String modelTypeName(Object? id) {
    final key = int.tryParse(_stringValue(id));
    if (key == null) return 'model_type ${_stringValue(id).isEmpty ? '-' : id}';
    return _stringValue(modelTypes[key]?['name']).isEmpty
        ? 'model_type $id'
        : _stringValue(modelTypes[key]?['name']);
  }

  String attributeKey(Object? id) {
    final key = int.tryParse(_stringValue(id));
    if (key == null) return 'attribute ${_stringValue(id).isEmpty ? '-' : id}';
    return _stringValue(attributeDefinitions[key]?['key']).isEmpty
        ? 'attribute $id'
        : _stringValue(attributeDefinitions[key]?['key']);
  }
}

String _stringValue(Object? value) => value?.toString() ?? '';
