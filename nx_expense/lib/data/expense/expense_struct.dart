import 'package:nx_db/kgql.dart';

import 'package:nx_expense/domain/expense/model_names.dart';

Map<String, dynamic> _buildExpenseBaseStruct(ModelType schema) {
  final struct = <String, dynamic>{
    'id': true,
    'name': true,
    'description': true,
    'created_at': true,
    'tags': true,
  };

  for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
    final k = ad.key;
    if (k != null && k.isNotEmpty) {
      struct[k] = true;
    }
  }

  for (final rel in schema.relations ?? const <RelationshipType>[]) {
    final link = rel.link;
    if (link is String && link.isNotEmpty) {
      struct[link] = {'id': true, 'name': true};
    }
  }

  return struct;
}

/// Builds the compact struct used by expense collection reads.
///
/// Relation names remain available for list cards, while expensive relation
/// edge attributes and rich related-model fields are reserved for detail reads.
Map<String, dynamic> buildExpenseListStruct(ModelType schema) =>
    _buildExpenseBaseStruct(schema);

/// Builds the complete struct used when loading one expense for its detail UI.
Map<String, dynamic> buildExpenseDetailStruct(ModelType schema) {
  final struct = _buildExpenseBaseStruct(schema);

  for (final rel in schema.relations ?? const <RelationshipType>[]) {
    final link = rel.link;
    if (link is String && link.isNotEmpty) {
      if (link == kTransferModelTypeName) {
        struct[link] = {
          'id': true,
          'name': true,
          'description': true,
          'created_at': true,
          'amount': true,
          'date': true,
          'to': true,
          'Company': {'id': true, 'name': true},
        };
      } else if (link == kProductModelTypeName) {
        struct[link] = {
          'id': true,
          'name': true,
          'brand': true,
          'image_url': true,
          'item_url': true,
        };
      }
    }
  }

  struct['relations'] = {
    'relation_id': true,
    'model_id': true,
    'model_type': true,
    'name': true,
    'description': true,
    'relation_attributes': {'key': true, 'value': true, 'value_type': true},
  };

  return struct;
}

/// Backward-compatible name for callers that require the complete struct.
Map<String, dynamic> buildExpenseStruct(ModelType schema) =>
    buildExpenseDetailStruct(schema);
