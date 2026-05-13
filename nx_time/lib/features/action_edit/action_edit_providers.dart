import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/action_edit/action_category_option.dart';

/// Picker rows: DB-backed type names + resolved dots (aligned with Today list).
final actionCategoryOptionsProvider =
    FutureProvider<List<ActionCategoryOption>>((ref) async {
      final types = await ref.watch(actionSubtypeModelTypesProvider.future);
      final colors = modelTypeColorsOrFallback(
        ref.watch(modelTypeColorsProvider),
      );
      return types
          .map(
            (t) => ActionCategoryOption(
              modelTypeId: t.id,
              name: t.name,
              dotColor: colors.forId(t.id, name: t.name),
            ),
          )
          .toList();
    });
