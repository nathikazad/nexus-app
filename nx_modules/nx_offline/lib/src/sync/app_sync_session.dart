typedef AppSyncRequest =
    Future<Map<String, dynamic>> Function(
      String operation,
      Map<String, dynamic> variables,
    );

const appStateSyncEnabled = bool.fromEnvironment('NX_APP_STATE_SYNC');

final class AppSyncManifest {
  AppSyncManifest(
    this.revision,
    this.root,
    this.collections,
    Iterable<Map<String, dynamic>> entries,
  ) : entries = List.unmodifiable(entries);
  final int revision;
  final String root;
  final Map<String, dynamic> collections;
  final List<Map<String, dynamic>> entries;
}

/// Remote manifest cache only. Local integrity and pending writes remain the
/// responsibility of the existing reconcilers, including on an equal root.
final class AppSyncSession {
  AppSyncSession({required this.request});
  final AppSyncRequest request;
  AppSyncManifest? _manifest;

  Future<AppSyncManifest?> manifest() async {
    final state = await request('state', {});
    if (state['status'] == 'unsupported') return null;
    if (state['status'] != 'ready') {
      throw StateError('Remote state is still being prepared');
    }
    if (state['projection_version'] != 1) {
      throw StateError('Unsupported app projection version');
    }
    final revision = state['revision'] as int;
    final root = state['root_hash'] as String;
    final previous = _manifest;
    if (previous != null && previous.revision > revision) return previous;
    if (previous?.root == root) {
      return _manifest = AppSyncManifest(
        revision,
        root,
        previous!.collections,
        previous.entries,
      );
    }
    final collections = Map<String, dynamic>.from(state['collections'] as Map);
    final changed = <String>{
      for (final key in collections.keys)
        if (previous?.collections[key]?['hash'] != collections[key]['hash'])
          key,
      if (previous != null)
        ...previous.collections.keys.where(
          (key) => !collections.containsKey(key),
        ),
    };
    final entries = <int, Map<String, dynamic>>{
      if (previous != null)
        for (final entry in previous.entries)
          if (!(entry['collections'] as List).any(changed.contains))
            entry['id'] as int: entry,
    };
    final selected = previous == null
        ? null
        : (changed.where(collections.containsKey).toList()..sort());
    final pages = selected == null
        ? <List<String>?>[null]
        : <List<String>?>[
            for (var offset = 0; offset < selected.length; offset += 200)
              selected.skip(offset).take(200).toList(),
          ];
    for (final page in pages) {
      final response = await request('snapshot', {
        'revision': '$revision',
        'collectionIds': page,
      });
      _checkRevision(response, revision);
      for (final raw in response['manifest'] as List) {
        final entry = Map<String, dynamic>.from(raw as Map);
        if (entry['id'] is! int ||
            entry['hash'] is! String ||
            entry['collections'] is! List) {
          throw StateError('Invalid app manifest');
        }
        entries[entry['id'] as int] = entry;
      }
    }
    final ordered = entries.values.toList()
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    final result = AppSyncManifest(revision, root, collections, ordered);
    // Parallel foreground/library checks cannot regress the remote cache.
    if (_manifest == null || _manifest!.revision <= revision) {
      _manifest = result;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> download(
    AppSyncManifest manifest,
    Set<int> ids,
  ) async {
    final expected = {
      for (final e in manifest.entries) e['id'] as int: e['hash'] as String,
    };
    final requested = ids.where(expected.containsKey).toList()..sort();
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; offset < requested.length; offset += 200) {
      final page = requested.skip(offset).take(200).toSet();
      final response = await request('snapshot', {
        'revision': '${manifest.revision}',
        'itemIds': page.toList(),
        'collectionIds': <String>[],
      });
      _checkRevision(response, manifest.revision);
      final received = <int>{};
      for (final raw in response['items'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = item['id'] as int;
        if (!page.contains(id) ||
            !received.add(id) ||
            item['hash'] != expected[id] ||
            item['payload'] is! Map) {
          throw StateError('Item does not match its advertised snapshot');
        }
        result.add(item);
      }
      if (received.length != page.length) {
        throw StateError('Incomplete app snapshot');
      }
    }
    return result;
  }

  void _checkRevision(Map<String, dynamic> response, int revision) {
    if (response['status'] != 'ready' || response['revision'] != revision) {
      throw StateError('Remote state changed; refresh the manifest');
    }
  }
}
