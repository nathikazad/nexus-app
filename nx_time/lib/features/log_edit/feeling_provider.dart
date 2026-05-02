import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_time/data/log/log_attr_keys.dart';
import 'package:nx_time/data/providers.dart';

/// Flat list of available feeling-tag node names from the personal-domain
/// `Feeling` tag system on Daily Log. Empty list if the tag system is missing
/// or has no nodes.
final feelingNamesProvider = FutureProvider<List<String>>((ref) async {
  final schema = await ref.watch(logSchemaProvider.future);
  final systems = schema.tagSystems ?? const <TagSystem>[];
  TagSystem? feeling;
  for (final s in systems) {
    if (s.name == kDailyLogFeelingTagSystemName) {
      feeling = s;
      break;
    }
  }
  if (feeling == null) return const [];
  final names = <String>[];
  void walk(List<TagNode> ns) {
    for (final n in ns) {
      names.add(n.name);
      final children = n.children;
      if (children != null && children.isNotEmpty) walk(children);
    }
  }

  walk(feeling.nodes);
  return names;
});
