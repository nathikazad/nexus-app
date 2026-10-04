import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'record_session.dart';
import 'record_graph.dart';
export 'record_session.dart'
    show
        AppSyncRequest,
        ManifestLoad,
        ManifestSave,
        AppSyncManifest,
        appStateSyncEnabled,
        appSyncProjectionVersion;

/// Canonical wire records are assembled into app views locally. No per-app
/// model payload exists on the server. Network identities are namespaced.
final class AppSyncSession {
  AppSyncSession({
    required AppSyncRequest request,
    this.load,
    this.save,
    this.app = 'generic',
  }) {
    _remote = RecordSyncSession(request: request, load: _restore);
  }
  final String app;
  final ManifestLoad? load;
  final ManifestSave? save;
  late final RecordSyncSession _remote;
  Map<String, Map<String, dynamic>> _records = {};
  Map<String, String> _hashes = {};
  Map<int, Map<String, dynamic>> _views = {};
  AppSyncManifest? _manifest;
  Future<AppSyncManifest?>? _active;
  Future<Map<String, dynamic>?> _restore() async {
    final data = await load?.call();
    if (data == null || data['version'] != appSyncProjectionVersion)
      return null;
    try {
      _records = {
        for (final e in (data['bodies'] as Map).entries)
          e.key as String: Map<String, dynamic>.from(e.value as Map),
      };
      _records.removeWhere((key, body) => !_validRecord(key, body));
      _hashes = Map<String, String>.from(data['hashes'] as Map);
      return data;
    } on Object {
      _records = {};
      _hashes = {};
      return null;
    }
  }

  Future<AppSyncManifest?> manifest() =>
      _active ??= _refresh().whenComplete(() => _active = null);
  Future<AppSyncManifest?> _refresh() async {
    final remote = (await _remote.manifest())!;
    if (_manifest?.root == remote.root) {
      return _manifest = AppSyncManifest(
        remote.revision,
        remote.root,
        remote.collections,
        _manifest!.entries,
      );
    }

    final wanted = <String>{
      for (final e in remote.entries)
        if (_hashes[e['id']] != e['hash'] || !_records.containsKey(e['id']))
          e['id'] as String,
    };
    final bodies = await _remote.download(remote, wanted);
    final ids = remote.entries.map((e) => e['id']).toSet();
    final next = Map<String, Map<String, dynamic>>.of(_records)
      ..removeWhere((key, _) => !ids.contains(key));
    for (final row in bodies) {
      final key = row['id'] as String;
      final body = Map<String, dynamic>.from(row['payload'] as Map);
      if (!_validRecord(key, body))
        throw StateError('Invalid canonical record');
      next[key] = body;
    }
    final hashes = {
      for (final e in remote.entries) e['id'] as String: e['hash'] as String,
    };
    final graph = RecordGraph(next, hashes);
    final views = <int, Map<String, dynamic>>{};
    final entries = <Map<String, dynamic>>[];
    for (final entry in remote.entries) {
      if (entry['role'] == 'support') continue;
      final key = entry['id'] as String;
      final payload = graph.view(app, key);
      final id = payload['id'] as int;
      final hash =
          'v1:${sha256.convert(utf8.encode(jsonEncode(_ordered(payload))))}';
      if (views.containsKey(id))
        throw StateError('Duplicate app view identity');
      views[id] = {'id': id, 'hash': hash, 'payload': payload};
      entries.add({...entry, 'id': id, 'hash': hash});
    }
    final result = AppSyncManifest(
      remote.revision,
      remote.root,
      remote.collections,
      entries,
    );
    if (save != null && (_manifest?.root != remote.root || wanted.isNotEmpty)) {
      await save!({...remote.toJson(), 'bodies': next, 'hashes': hashes});
    }
    _records = next;
    _hashes = hashes;
    _views = views;
    _manifest = result;
    return result;
  }

  Future<List<Map<String, dynamic>>> download(
    AppSyncManifest manifest,
    Set<int> ids,
  ) async {
    if (_manifest?.root != manifest.root ||
        _manifest?.revision != manifest.revision) {
      throw StateError('Local app view changed; refresh its manifest');
    }
    return [
      for (final id in ids)
        if (_views.containsKey(id)) _views[id]!,
    ];
  }
}

Object? _ordered(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _ordered(value[key])};
  }
  if (value is List) return value.map(_ordered).toList();
  return value;
}

bool _validRecord(String key, Map<String, dynamic> body) {
  if (body['id'] is! int) return false;
  if (!key.startsWith('model:')) return true;
  return key == 'model:${body['id']}' &&
      body['model_type'] is Map &&
      (body['model_type'] as Map)['name'] is String;
}
