/// GraphQL document for `get_kgql_aggregate`.
const String getKgqlAggregateQuery = '''
query GetKgqlAggregate(\$filterkgql: JSON, \$aggregate: JSON) {
  getKgqlAggregate(filterkgql: \$filterkgql, aggregate: \$aggregate)
}
''';
