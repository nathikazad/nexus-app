import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/schema/schema_entity_mappers.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_list_query.dart';

void main() {
  test('query mapping preserves search, operators, sort and probe pagination',
      () {
    final query = schemaModelListQueryToNx(const SchemaModelListQuery(
      modelTypeId: 9,
      search: 'John',
      page: 2,
      filters: [
        SchemaModelFilter(
            key: 'name',
            valueType: 'string',
            operator: SchemaModelFilterOperator.like,
            value: 'McAfee'),
        SchemaModelFilter(
            key: 'age',
            valueType: 'number',
            operator: SchemaModelFilterOperator.greaterThanOrEqual,
            value: '18'),
      ],
      sort: SchemaModelSort(
          key: 'created_at', valueType: 'datetime', descending: true),
    ));
    expect(query.modelTypeId, 9);
    expect(query.search, 'John');
    expect(query.filters.first.key, 'name');
    expect(query.filters.first.op, 'LIKE');
    expect(query.filters.first.value, '%McAfee%');
    expect(query.filters.last.op, '>=');
    expect(query.filters.last.value, '18');
    expect(query.sort!.key, 'created_at');
    expect(query.sort!.descending, true);
    expect(query.offset, 100);
    expect(query.limit, 51);
  });
  test('default query has no filters or sort and starts at first page', () {
    final query =
        schemaModelListQueryToNx(const SchemaModelListQuery(modelTypeId: 1));
    expect(query.filters, isEmpty);
    expect(query.sort, isNull);
    expect(query.offset, 0);
    expect(query.limit, 51);
  });
}
