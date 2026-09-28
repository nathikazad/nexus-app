import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';

final personSchemaProvider = FutureProvider<ModelType>((ref) {
  ref.watch(peopleDataGenerationProvider);
  final data = ref.watch(peopleDataRepositoryProvider);
  return data?.schema('Person') ??
      ref.watch(kgqlModelTypeByNameProvider('Person').future);
});
