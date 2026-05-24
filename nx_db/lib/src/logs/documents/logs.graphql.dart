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
