import 'dart:async';

typedef AppSyncRequest =
    Future<Map<String, dynamic>> Function(
      String operation,
      Map<String, dynamic> variables,
    );
typedef ManifestLoad = Future<Map<String, dynamic>?> Function();
typedef ManifestSave = Future<void> Function(Map<String, dynamic> value);
const appStateSyncEnabled = true;
const appSyncProjectionVersion = 2;

final class AppSyncManifest {
  AppSyncManifest(
    this.revision,
    this.root,
    this.collections,
    Iterable<Map<String, dynamic>> entries, [
    this.branches = const {},
  ]) : entries = List.unmodifiable(entries);
  final int revision;
  final String root;
  final Map<String, dynamic> collections;
  final List<Map<String, dynamic>> entries;
  // Complete immediate record manifests for each visited group. This preserves
  // overlapping memberships and lets an unchanged branch survive a restart.
  final Map<String, dynamic> branches;
  Map<String, dynamic> toJson() => {
    'version': appSyncProjectionVersion,
    'revision': revision,
    'root': root,
    'collections': collections,
    'entries': entries,
    'branches': branches,
  };
  static AppSyncManifest? restore(Map<String, dynamic>? data) {
    if (data == null || data['version'] != appSyncProjectionVersion)
      return null;
    return AppSyncManifest(
      data['revision'] as int,
      data['root'] as String,
      Map<String, dynamic>.from(data['collections'] as Map),
      (data['entries'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      Map<String, dynamic>.from(data['branches'] as Map),
    );
  }
}

/// One protocol for root records, flat groups and arbitrary nested groups.
/// Published revisions are checked at every step; incomplete traversals are
/// never committed. Local bodies and pending edits remain app-owned.
final class AppSyncSession {
  AppSyncSession({required this.request, this.load, this.save});
  final AppSyncRequest request;
  final ManifestLoad? load;
  final ManifestSave? save;
  AppSyncManifest? _manifest;
  Future<AppSyncManifest?>? _active;
  bool _loaded = false;

  Future<AppSyncManifest?> manifest() =>
      _active ??= _readManifest().whenComplete(() => _active = null);

  Future<AppSyncManifest?> _readManifest() async {
    if (!_loaded) {
      try {
        _manifest = AppSyncManifest.restore(await load?.call());
      } on FormatException {
        _manifest = null;
      } on TypeError {
        _manifest = null;
      }
      _loaded = true;
    }
    final state = await request('state', {});
    if (state['status'] != 'ready')
      throw StateError('Remote state is being prepared');
    if (state['projection_version'] != appSyncProjectionVersion) {
      throw StateError('Incompatible app sync protocol; update the app/server');
    }
    final revision = state['revision'] as int;
    final root = state['root_hash'] as String;
    final previous = _manifest;
    if (previous != null && previous.revision > revision) {
      throw StateError('Remote sync revision regressed');
    }
    if (previous?.root == root) {
      final result = AppSyncManifest(
        revision,
        root,
        previous!.collections,
        previous.entries,
        previous.branches,
      );
      if (revision != previous.revision) await save?.call(result.toJson());
      return _manifest = result;
    }
    final rootNode = Map<String, dynamic>.from(
      (state['collections'] as Map)[''] as Map,
    );
    final nodes = <String, dynamic>{'': rootNode};
    final branches = <String, dynamic>{};
    final oldChildren = <String, List<String>>{};
    for (final entry
        in previous?.collections.entries ?? <MapEntry<String, dynamic>>[]) {
      if (entry.key.isNotEmpty)
        (oldChildren[entry.value['parent'] as String] ??= []).add(entry.key);
    }
    var pending = <String>[''];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final changed = <String>[];
      final next = <String>[];
      for (final key in pending) {
        if (!visited.add(key))
          throw StateError('Cycle or duplicate sync group');
        if (previous?.collections[key]?['hash'] == nodes[key]['hash'] &&
            previous!.branches.containsKey(key)) {
          branches[key] = previous.branches[key];
          for (final child in oldChildren[key] ?? <String>[]) {
            nodes[child] = previous.collections[child];
            next.add(child);
          }
        } else {
          changed.add(key);
        }
      }
      for (var offset = 0; offset < changed.length; offset += 200) {
        final selected = changed.skip(offset).take(200).toSet();
        final response = await request('snapshot', {
          'revision': '$revision',
          'collectionIds': selected.toList(),
        });
        _checkRevision(response, revision);
        final children = Map<String, dynamic>.from(
          response['collections'] as Map,
        );
        final records = (response['manifest'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final key in selected) branches[key] = <Map<String, dynamic>>[];
        final received = <int>{};
        for (final record in records) {
          if (record['id'] is! int ||
              !received.add(record['id']) ||
              record['hash'] is! String ||
              record['collections'] is! List) {
            throw StateError('Invalid record manifest');
          }
          final memberships = (record['collections'] as List).where(
            selected.contains,
          );
          if (memberships.isEmpty)
            throw StateError('Unexpected manifest record');
          for (final key in memberships) (branches[key] as List).add(record);
        }
        for (final child in children.entries) {
          if (child.key.isEmpty ||
              nodes.containsKey(child.key) ||
              !selected.contains(child.value['parent']) ||
              child.value['hash'] is! String) {
            throw StateError('Invalid sync child group');
          }
          nodes[child.key] = child.value;
          next.add(child.key);
        }
        for (final key in selected) {
          if ((branches[key] as List).length != nodes[key]['count'] ||
              children.values.where((v) => v['parent'] == key).length !=
                  nodes[key]['child_count']) {
            throw StateError('Incomplete sync branch');
          }
        }
      }
      pending = next;
    }
    final records = <int, Map<String, dynamic>>{};
    final memberships = <int, Set<String>>{};
    for (final branch in branches.entries) {
      for (final raw in branch.value as List) {
        final record = Map<String, dynamic>.from(raw as Map);
        final id = record['id'] as int;
        if (records[id] != null && records[id]!['hash'] != record['hash']) {
          throw StateError('Inconsistent record across sync branches');
        }
        records[id] = record;
        (memberships[id] ??= {}).add(branch.key);
      }
    }
    for (final entry in records.entries) {
      entry.value['collections'] = memberships[entry.key]!.toList()..sort();
    }
    final ordered = records.values.toList()
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    final result = AppSyncManifest(revision, root, nodes, ordered, branches);
    await save?.call(result.toJson());
    return _manifest = result;
  }

  Future<List<Map<String, dynamic>>> download(
    AppSyncManifest manifest,
    Set<int> ids,
  ) async {
    final expected = {
      for (final e in manifest.entries) e['id'] as int: e['hash'],
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
      if (received.length != page.length)
        throw StateError('Incomplete app snapshot');
    }
    return result;
  }

  void _checkRevision(Map<String, dynamic> response, int revision) {
    if (response['status'] != 'ready' ||
        response['revision'] != revision ||
        response['projection_version'] != appSyncProjectionVersion) {
      throw StateError('Remote state changed; refresh the manifest');
    }
  }
}
