library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_sync/nx_sync.dart';
import 'nx_db.dart';

export 'package:nx_sync/nx_sync.dart' show appStateSyncEnabled;

/// Diagnostic metadata only: never pass record contents, credentials or errors' text.
void syncTrace(String event, Map<String, Object?> fields) {
  debugPrint(
    'sync_timing ${jsonEncode({'event': event, 'at': DateTime.now().toUtc().toIso8601String(), ...fields})}',
  );
}

String _encodeManifest(Map<String, dynamic> value) => jsonEncode(value);
Map<String, dynamic> _decodeManifest(String value) =>
    Map<String, dynamic>.from(jsonDecode(value) as Map);

final appSyncChangesProvider = Provider.family<Stream<String>?, String>((
  ref,
  app,
) {
  if (!appStateSyncEnabled || ref.watch(authProvider).value?.domainId == null)
    return null;
  final client = ref.watch(graphqlClientProvider);
  return client
      .subscribe(
        SubscriptionOptions(
          document: gql(r'''
    subscription AppSyncChanged($app:String!,$domainId:Int!) { appSyncChanged(app:$app,domainId:$domainId) }
  '''),
          variables: {'app': app, 'domainId': domainForClient(client)},
          fetchPolicy: FetchPolicy.noCache,
        ),
      )
      .where((result) {
        if (result.hasException) {
          syncTrace('subscription_error', {
            'app': app,
            'domain_id': domainForClient(client),
          });
          return false;
        }
        final raw = result.data?['appSyncChanged'];
        Object? hint = raw;
        if (raw is String) {
          try {
            hint = jsonDecode(raw);
          } on FormatException {
            // Diagnostics must not change handling of an unexpected payload.
            hint = null;
          }
        }
        syncTrace('socket_hint_received', {
          'app': app,
          'domain_id': domainForClient(client),
          if (hint is Map) 'revision': hint['revision'],
          if (hint is Map) 'status': hint['status'],
        });
        return true;
      })
      .map((result) => jsonEncode(result.data?['appSyncChanged']));
});

final class AppSyncClient {
  AppSyncClient(this.client, this.app) {
    session = AppSyncSession(
      request: _request,
      app: app,
      load: _loadManifest,
      save: _saveManifest,
    );
  }
  final GraphQLClient client;
  final String app;
  late final AppSyncSession session;
  Future<Map<String, dynamic>?> _loadManifest() async {
    final key = syncStorageKeyForClient(client, app);
    if (kIsWeb || key == null) return null;
    final library = FileLibrary.application(key);
    try {
      final raw = await library.read('sync_tree', 'manifest');
      return raw == null ? null : await compute(_decodeManifest, raw);
    } on Exception {
      return null;
    } finally {
      await library.close();
    }
  }

  Future<void> _saveManifest(Map<String, dynamic> value) async {
    final key = syncStorageKeyForClient(client, app);
    if (kIsWeb || key == null) return;
    final library = FileLibrary.application(key);
    try {
      await library.saveRemote(
        'sync_tree',
        'manifest',
        await compute(_encodeManifest, value),
      );
    } finally {
      await library.close();
    }
  }

  String? _refreshedRoot;
  Map<String, dynamic> _collections = {};

  /// Browser repositories refresh their existing views only when state changes.
  /// A failed refresh never advances the locally applied root.
  Future<void> refreshIfChanged(
    Future<void> Function() refresh, {
    void Function(Map<String, dynamic> previous, Map<String, dynamic> current)?
    invalidate,
  }) async {
    final state = await _request('state', {});
    if (state['status'] != 'ready' ||
        state['projection_version'] != appSyncProjectionVersion) {
      throw StateError('Remote app state is not ready');
    }
    final root = state['root_hash'] as String;
    if (root == _refreshedRoot) return;
    final collections = Map<String, dynamic>.from(
      state['collections'] as Map? ?? {},
    );
    invalidate?.call(_collections, collections);
    await refresh();
    _collections = collections;
    _refreshedRoot = root;
  }

  static final _instances = Expando<AppSyncClient>();
  static AppSyncClient forOwner(
    Object owner,
    GraphQLClient client,
    String app,
  ) {
    final previous = _instances[owner];
    if (previous != null &&
        identical(previous.client, client) &&
        previous.app == app)
      return previous;
    return _instances[owner] = AppSyncClient(client, app);
  }

  Future<Map<String, dynamic>> _request(
    String operation,
    Map<String, dynamic> variables,
  ) async {
    final timer = Stopwatch()..start();
    final state = operation == 'state';
    try {
      final response = await client.query(
        QueryOptions(
          document: gql(
            state
                ? r'''
      query AppSyncState($app:String!,$domainId:Int!) { appSyncState(app:$app,domainId:$domainId) }
    '''
                : r'''
      query AppSyncSnapshot($app:String!,$domainId:Int!,$revision:String!,$itemIds:[String!],$collectionIds:[String!]) {
        appSyncSnapshot(app:$app,domainId:$domainId,revision:$revision,itemIds:$itemIds,collectionIds:$collectionIds)
      }
    ''',
          ),
          variables: {
            ...variables,
            'app': app,
            'domainId': domainForClient(client),
          },
          fetchPolicy: FetchPolicy.noCache,
          queryRequestTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.hasException) {
        throw response.exception!;
      }
      final raw = response.data?[state ? 'appSyncState' : 'appSyncSnapshot'];
      final result = Map<String, dynamic>.from(
        (raw is String ? jsonDecode(raw) : raw) as Map,
      );
      syncTrace('client_$operation', {
        'app': app,
        'domain_id': domainForClient(client),
        'status': result['status'],
        'revision': result['revision'] ?? variables['revision'],
        'duration_ms': timer.elapsedMilliseconds,
      });
      return result;
    } catch (error) {
      syncTrace('client_request_failed', {
        'app': app,
        'operation': operation,
        'domain_id': domainForClient(client),
        'duration_ms': timer.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
      });
      rethrow;
    }
  }

  Future<DocumentSyncResponse?> documents({
    required List<Map<String, Object?>> localManifest,
    Set<int>? ids,
    bool manifestOnly = false,
  }) async {
    if (!appStateSyncEnabled) return null;
    final remote = await session.manifest();
    if (remote == null) return null;
    final local = {for (final e in localManifest) e['id'] as int: e['hash']};
    final entries = remote.entries.where(
      (e) => ids == null || ids.contains(e['id']),
    );
    final wanted = {
      for (final e in entries)
        if (!manifestOnly && local[e['id']] != e['hash']) e['id'] as int,
    };
    final bodies = await session.download(remote, wanted);
    final remoteIds = remote.entries.map((e) => e['id']).toSet();
    return DocumentSyncResponse(
      manifest: [
        for (final e in entries)
          DocumentHashEntry(
            e['id'] as int,
            e['model_type'] as String,
            e['hash'] as String,
          ),
      ],
      documents: [
        for (final e in bodies)
          DocumentSyncEntry(
            documentId: e['id'] as int,
            syncHash: e['hash'] as String,
            document: Map<String, dynamic>.from(e['payload'] as Map),
          ),
      ],
      deletedIds: [
        for (final id in ids ?? local.keys.toSet())
          if (!remoteIds.contains(id)) id,
      ],
      topicTags: ({
        for (final value in remote.collections.values)
          ...((value['metadata']?['topics'] as List?) ?? const [])
              .cast<String>(),
        for (final value in remote.collections.values)
          if (value['metadata']?['kind'] == 'Topic')
            value['metadata']['name'] as String,
      }.toList()..sort()),
    );
  }
}
