/// A validated incremental download, including explicit intervening deletions.
final class HashDownload<K, V> {
  const HashDownload(this.values, {this.deleted = const {}});
  final List<V> values;
  final Set<K> deleted;
}

/// Shared manifest reconciliation for file-backed libraries. Applications own
/// hashes, pending-edit protection and publication of the completed manifest.
Future<List<E>> reconcileHashManifest<K, E, V>({
  required List<E> manifest,
  required K Function(E) keyOf,
  required K Function(V) valueKeyOf,
  required Future<bool> Function(E) verified,
  required Future<HashDownload<K, V>> Function(Set<K>) download,
  required Future<List<K>> Function(List<V>) applyBatch,
  Future<void> Function(
    bool downloading,
    int total,
    int verified,
    List<K> failed,
  )?
  report,
}) async {
  final entries = [...manifest];
  if (entries.map(keyOf).toSet().length != entries.length) {
    throw StateError('Duplicate items in server manifest');
  }
  var done = 0;
  final missing = <K>{};
  final failed = <K>[];
  for (var offset = 0; offset < entries.length; offset += 8) {
    final page = entries.skip(offset).take(8).toList();
    final checks = await Future.wait(page.map(verified));
    for (var i = 0; i < page.length; i++) {
      if (checks[i]) {
        done++;
      } else {
        missing.add(keyOf(page[i]));
      }
    }
    if (offset % 64 == 0) {
      await report?.call(false, entries.length, done, failed);
    }
    await Future<void>.delayed(Duration.zero);
  }
  await report?.call(true, entries.length, done, failed);
  if (missing.isNotEmpty) {
    final bundle = await download(missing);
    final received = <K>{};
    for (final value in bundle.values) {
      final key = valueKeyOf(value);
      if (!missing.contains(key) ||
          !received.add(key) ||
          bundle.deleted.contains(key)) {
        throw StateError('Unexpected item in sync response');
      }
    }
    for (var offset = 0; offset < bundle.values.length; offset += 25) {
      final page = bundle.values.skip(offset).take(25).toList();
      final failures = await applyBatch(page);
      failed.addAll(failures);
      done += page.length - failures.length;
      await report?.call(true, entries.length, done, failed);
      await Future<void>.delayed(Duration.zero);
    }
    for (final key in missing.difference(received)) {
      if (bundle.deleted.contains(key)) {
        entries.removeWhere((entry) => keyOf(entry) == key);
      } else {
        failed.add(key);
      }
    }
  }
  await report?.call(true, entries.length, done, failed);
  if (failed.isNotEmpty) {
    throw StateError('${failed.length} items could not be saved');
  }
  return entries;
}
