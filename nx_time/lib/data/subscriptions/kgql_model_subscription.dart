import 'dart:async';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/person.dart';
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
      final domainId = ref.watch(authenticatedUserProvider).value?.domainId;
      if (domainId == null) return;
      final client = ref.watch(graphqlClientProvider);
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

/// Merge selected workspaces plus personal activity; each subscription retains
/// the same explicit domain as its transport client.
final workspaceChangesProvider = StreamProvider.autoDispose<KgqlModelChange>((
  ref,
) async* {
  final workspace = await ref.watch(timeDomainsProvider.future);
  final controller = StreamController<KgqlModelChange>();
  final subscriptions = <StreamSubscription<QueryResult>>[];
  ref.onDispose(() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    controller.close();
  });
  for (final id in {...workspace.selectedIds, workspace.personalId}) {
    subscriptions.add(
      workspace.clients[id]!
          .subscribe(
            SubscriptionOptions(
              document: gql(_subscribeKgqlModelsSubscription),
              variables: {'filter': <String, dynamic>{}, 'domainId': id},
              fetchPolicy: FetchPolicy.noCache,
            ),
          )
          .listen(
            (result) {
              if (controller.isClosed) return;
              final change = KgqlModelChange.fromJson(
                result.data?['subscribeKgqlModels'],
              );
              if (change != null) controller.add(change);
            },
            onError: (Object error) {
              /* Refresh-on-resume remains available offline. */
            },
          ),
    );
  }
  yield* controller.stream;
});
