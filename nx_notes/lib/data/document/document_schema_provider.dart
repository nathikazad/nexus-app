import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_notes/data/document/document_attr_keys.dart';

final documentSchemaProvider = kgqlModelTypeByNameProvider(
  kDocumentModelTypeName,
);

final documentSnapSchemaProvider = kgqlModelTypeByNameProvider(
  kDocumentSnapModelTypeName,
);

final documentTagSystemsProvider = FutureProvider<List<TagSystem>>((ref) async {
  final schema = await ref.watch(documentSchemaProvider.future);
  return schema.tagSystems ?? const <TagSystem>[];
});
