import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/data/action/action_subtypes_provider.dart';
import 'package:nx_time/features/action_edit/action_category_option.dart';

/// Picker rows: DB-backed type names + [barColorForModelTypeId] dots (aligned with Today list).
final actionCategoryOptionsProvider =
    FutureProvider<List<ActionCategoryOption>>((ref) async {
  final types = await ref.watch(actionSubtypeModelTypesProvider.future);
  return types
      .map(
        (t) => ActionCategoryOption(
          modelTypeId: t.id,
          name: t.name,
          dotColor: barColorForModelTypeId(t.id),
        ),
      )
      .toList();
});
