import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/nx_db.dart' as nx;

/// Thin Riverpod-bound wrapper around `nx_db` KGQL model fetch / set helpers.
class KgqlModelRepository {
  KgqlModelRepository(this._ref);

  final Ref _ref;

  GraphQLClient get _client => _ref.read(nx.graphqlClientProvider);

  Future<List<nx.Model>> fetchModels({
    required Map<String, dynamic> filter,
    required Map<String, dynamic> struct,
  }) {
    return nx.fetchKgqlModels(_client, filter: filter, struct: struct);
  }

  Future<nx.Model?> fetchModelById({
    required String modelTypeName,
    required int id,
    required Map<String, dynamic> struct,
  }) {
    return nx.fetchKgqlModelById(
      _client,
      modelTypeName: modelTypeName,
      id: id,
      struct: struct,
    );
  }

  Future<List<nx.Model>> fetchModelsForRelationPicker(String modelTypeName) {
    return nx.fetchKgqlModelsForRelationPicker(_client, modelTypeName);
  }

  Future<int> setModel(nx.SetModelRequest request) {
    return nx.setKgqlModel(_client, request);
  }
}

final kgqlModelRepositoryProvider = Provider<KgqlModelRepository>((ref) {
  return KgqlModelRepository(ref);
});
