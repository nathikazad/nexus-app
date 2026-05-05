import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_notes/data/essay/essay_attr_keys.dart';

final essaySchemaProvider = kgqlModelTypeForPersonalDomain(kEssayModelTypeName);

final essaySnapSchemaProvider = kgqlModelTypeForPersonalDomain(
  kEssaySnapModelTypeName,
);

final essayTagSystemsProvider = FutureProvider<List<TagSystem>>((ref) async {
  final schema = await ref.watch(essaySchemaProvider.future);
  return schema.tagSystems ?? const <TagSystem>[];
});
