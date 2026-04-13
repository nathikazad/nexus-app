import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

/// Per-model failures from bulk update (id → error message).
class BulkApplyResult {
  BulkApplyResult({required this.failures});

  final Map<int, String> failures;

  bool get hasFailures => failures.isNotEmpty;
}

/// Applies tag assignment for a single tag [systemName] to each expense [ids].
/// Only that system is sent; other tag systems are unchanged (server merge).
Future<BulkApplyResult> bulkApplyTag({
  required WidgetRef ref,
  required List<int> ids,
  required String systemName,
  required List<String> nodes,
}) async {
  final failures = <int, String>{};
  final container = ref.container;

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
      );
    } catch (e) {
      failures[id] = e.toString();
    }
  }

  return BulkApplyResult(failures: failures);
}

/// Sets relation [targetTypeName] links to [linkIds] for each expense [ids].
Future<BulkApplyResult> bulkApplyRelation({
  required WidgetRef ref,
  required List<int> ids,
  required String targetTypeName,
  required List<int> linkIds,
}) async {
  final failures = <int, String>{};
  final container = ref.container;

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
      );
    } catch (e) {
      failures[id] = e.toString();
    }
  }

  return BulkApplyResult(failures: failures);
}
