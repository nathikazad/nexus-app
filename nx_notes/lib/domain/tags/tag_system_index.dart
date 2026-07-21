import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';

List<TagSystem> tagSystemsFromDocuments(Iterable<NxDocument> documents) {
  final countsBySystem = <String, Map<String, int>>{};
  for (final document in documents) {
    for (final entry in document.tagsBySystem.entries) {
      final systemName = entry.key.trim();
      if (systemName.isEmpty) continue;
      final counts = countsBySystem.putIfAbsent(
        systemName,
        () => <String, int>{},
      );
      for (final rawTag in entry.value.toSet()) {
        final tag = rawTag.trim();
        if (tag.isEmpty) continue;
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
  }

  final systemNames = countsBySystem.keys.toList()
    ..sort(_compareCaseInsensitive);
  return <TagSystem>[
    for (final systemName in systemNames)
      TagSystem(name: systemName, nodes: _nodes(countsBySystem[systemName]!)),
  ];
}

List<TagNode> _nodes(Map<String, int> counts) {
  final names = counts.keys.toList()..sort(_compareCaseInsensitive);
  return <TagNode>[
    for (final name in names) TagNode(name: name, count: counts[name]!),
  ];
}

int _compareCaseInsensitive(String left, String right) {
  final comparison = left.toLowerCase().compareTo(right.toLowerCase());
  return comparison != 0 ? comparison : left.compareTo(right);
}
