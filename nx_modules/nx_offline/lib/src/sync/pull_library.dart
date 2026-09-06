/// Discover lightweight keys, reconcile bounded pages, and persist each page
/// before fetching the next. Apps own revisions, transport and merge rules.
Future<void> pullLibrary<K>({
  required Future<Iterable<K>> Function() discover,
  required Future<void> Function(Set<K>) reconcilePage,
  Iterable<K> knownKeys = const [],
  int pageSize = 20,
  Comparator<K>? compare,
}) async {
  if (pageSize < 1) throw ArgumentError.value(pageSize, 'pageSize');
  final keys = {...await discover(), ...knownKeys}.toList();
  if (compare != null) keys.sort(compare);
  for (var offset = 0; offset < keys.length; offset += pageSize) {
    await reconcilePage(keys.skip(offset).take(pageSize).toSet());
  }
}
