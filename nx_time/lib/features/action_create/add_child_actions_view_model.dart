import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';

/// Key for reloading a parent [Action] (with `childActionIds` / relation ids).
typedef ParentActionKey = ({int id, String modelTypeName});

/// Refetches the parent after linking/unlinking children.
final parentActionForChildrenProvider =
    FutureProvider.autoDispose.family<Action?, ParentActionKey>((ref, key) async {
  final repo = ref.read(actionRepositoryProvider);
  return repo.getById(
    id: key.id,
    modelTypeName: key.modelTypeName,
  );
});
