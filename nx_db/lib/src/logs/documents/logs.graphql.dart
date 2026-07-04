const logsForDayQuery = r'''
query LogsForDay($start: Datetime!, $end: Datetime!, $first: Int!) {
  logsForDay(start: $start, end: $end, first: $first)
}
''';

const changeOperationsForDayQuery = r'''
query ChangeOperationsForDay($start: Datetime!, $end: Datetime!, $first: Int!) {
  changeOperationsForDay(start: $start, end: $end, first: $first)
}
''';

const changeOperationQuery = r'''
query ChangeOperation($id: UUID!) {
  allChangeOperations(first: 1, condition: { id: $id }) {
    nodes {
      id
      createdAt
      txid
      userId
      domainId
      sourceKind
      sourceId
      sourceLabel
      reversalOfOperationId
      reversedAt
      reversedByOperationId
    }
  }
}
''';

const logByIdQuery = r'''
query LogById($id: BigInt!) {
  allLogs(first: 1, condition: { id: $id }) {
    nodes {
      time
      id
      payload
    }
  }
}
''';

const updateLogPayloadMutation = r'''
mutation UpdateLogPayload($time: Datetime!, $id: BigInt!, $payload: JSON!) {
  updateLogByTimeAndId(
    input: {
      time: $time
      id: $id
      logPatch: { payload: $payload }
    }
  ) {
    log {
      time
      id
      payload
    }
  }
}
''';

const changeEventsQuery = r'''
query ChangeEvents($operationId: UUID!) {
  allChangeEvents(
    first: 200
    condition: { operationId: $operationId }
    orderBy: [ID_ASC]
  ) {
    nodes {
      id
      operationId
      occurredAt
      tableName
      op
      rowPk
      beforeRow
      afterRow
    }
  }
}
''';

const dbChangeMetadataQuery = r'''
query DbChangeMetadata {
  allModelTypes(first: 10000) {
    nodes { id name }
  }
  allAttributeDefinitions(first: 10000) {
    nodes { id modelTypeId key valueType }
  }
  allRelationshipTypes(first: 10000) {
    nodes { id fromModelTypeId toModelTypeId relationName }
  }
  allRelationAttributeDefinitions(first: 10000) {
    nodes { id relationshipTypeId key valueType }
  }
}
''';
