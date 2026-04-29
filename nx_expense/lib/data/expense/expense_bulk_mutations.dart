import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart'
    show
        SetModelRequest,
        SetModelTag,
        ModelRelation,
        createModel,
        homeDomainIdProvider;

/// Bulk tag / relation updates for expenses (KGQL).
class ExpenseBulkMutationResult {
  ExpenseBulkMutationResult({required this.failures});

  final Map<int, String> failures;

  bool get hasFailures => failures.isNotEmpty;
}

Future<ExpenseBulkMutationResult> bulkApplyExpenseTags({
  required ProviderContainer container,
  required List<int> ids,
  required String systemName,
  required List<String> nodes,
}) async {
  final failures = <int, String>{};
  final home = container.read(homeDomainIdProvider);
  if (home == null) {
    throw StateError('homeDomainId required (login)');
  }
  for (final id in ids) {
    try {
      final tags = <SetModelTag>[
        if (nodes.isEmpty)
          SetModelTag(system: systemName, nodes: const [], clear: true)
        else
          SetModelTag(system: systemName, nodes: nodes),
      ];
      await createModel(
        container,
        SetModelRequest(id: id, tags: tags),
        domainId: home,
      );
    } catch (e) {
      failures[id] = e.toString();
    }
  }
  return ExpenseBulkMutationResult(failures: failures);
}

Future<ExpenseBulkMutationResult> bulkApplyExpenseRelations({
  required ProviderContainer container,
  required List<int> ids,
  required String targetTypeName,
  required List<int> linkIds,
}) async {
  final failures = <int, String>{};
  final home = container.read(homeDomainIdProvider);
  if (home == null) {
    throw StateError('homeDomainId required (login)');
  }
  for (final id in ids) {
    try {
      await createModel(
        container,
        SetModelRequest(
          id: id,
          relations: [
            ModelRelation(
              modelType: targetTypeName,
              link: linkIds,
            ),
          ],
        ),
        domainId: home,
      );
    } catch (e) {
      failures[id] = e.toString();
    }
  }
  return ExpenseBulkMutationResult(failures: failures);
}
