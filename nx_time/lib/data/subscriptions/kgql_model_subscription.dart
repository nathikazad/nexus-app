import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';

const String _subscribeKgqlModelsSubscription = '''
subscription SubscribeKgqlModels(\$filter: JSON!, \$domainId: Int!) {
  subscribeKgqlModels(filter: \$filter, domainId: \$domainId) {
    operation
    modelId
    modelTypeName
    domainId
  }
}
''';

class KgqlModelChange {
  const KgqlModelChange({
    required this.operation,
    required this.modelId,
    required this.modelTypeName,
    required this.domainId,
  });

  final String operation;
  final int modelId;
  final String? modelTypeName;
  final int domainId;

  static KgqlModelChange? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final operation = raw['operation'];
    final modelId = raw['modelId'];
    final modelTypeName = raw['modelTypeName'];
    final domainId = raw['domainId'];
    if (operation is! String || modelId is! int || domainId is! int) {
      return null;
    }
    return KgqlModelChange(
      operation: operation,
      modelId: modelId,
      modelTypeName: modelTypeName is String ? modelTypeName : null,
      domainId: domainId,
    );
  }
}

final kgqlModelChangesProvider = StreamProvider.autoDispose
    .family<KgqlModelChange, String>((ref, modelTypeName) async* {
      final client = ref.watch(graphqlClientProvider);
      final domainOptions = await fetchModelTypeDomainOptions(
        client,
        modelTypeName: modelTypeName,
      );
      final domainId = _subscriptionDomainId(domainOptions);
      if (domainId == null) {
        throw StateError('No domain available for $modelTypeName subscription');
      }
      final options = SubscriptionOptions(
        document: gql(_subscribeKgqlModelsSubscription),
        variables: {
          'filter': {'model_type': modelTypeName},
          'domainId': domainId,
        },
        fetchPolicy: FetchPolicy.noCache,
      );

      await for (final result in client.subscribe(options)) {
        if (result.hasException) {
          continue;
        }
        final change = KgqlModelChange.fromJson(
          result.data?['subscribeKgqlModels'],
        );
        if (change != null) {
          yield change;
        }
      }
    });

int? _subscriptionDomainId(ModelTypeDomainOptions domainOptions) {
  if (domainOptions.domains.isEmpty) return null;
  return domainOptions.domains.first.id;
}
