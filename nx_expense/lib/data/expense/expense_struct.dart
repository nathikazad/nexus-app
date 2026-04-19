import 'package:nx_db/kgql.dart';

import 'package:nx_expense/domain/expense/model_names.dart';

/// Builds the `struct` for `get_kgql_models` from an Expense [ModelType].
Map<String, dynamic> buildExpenseStruct(ModelType schema) {
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
      } else {
        struct[link] = {'id': true, 'name': true};
      }
    }
  }

  struct['relations'] = {
    'relation_id': true,
    'model_id': true,
    'model_type': true,
  };

  return struct;
}
