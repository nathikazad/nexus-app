/// GraphQL document for `get_kgql_aggregate`.
const String getKgqlAggregateQuery = '''
query GetKgqlAggregate(\$filterkgql: JSON, \$aggregate: JSON, \$domainId: Int!) {
  getKgqlAggregate(filterkgql: \$filterkgql, aggregate: \$aggregate, domainId: \$domainId)
}
''';
