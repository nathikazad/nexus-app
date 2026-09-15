library;

import 'dart:convert';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_sync/nx_sync.dart';
import 'nx_db.dart';

export 'package:nx_sync/nx_sync.dart' show appStateSyncEnabled;

final appSyncChangesProvider = Provider.family<Stream<String>?, String>((
  ref,
  app,
) {
  if (!appStateSyncEnabled || ref.watch(authProvider).value == null)
    return null;
  final client = ref.watch(graphqlClientProvider);
  return client
      .subscribe(
        SubscriptionOptions(
          document: gql(r'''
    subscription AppSyncChanged($app:String!) { appSyncChanged(app:$app) }
  '''),
          variables: {'app': app},
          fetchPolicy: FetchPolicy.noCache,
        ),
      )
      .where((result) => !result.hasException)
      .map((result) => jsonEncode(result.data?['appSyncChanged']));
});

final class AppSyncClient {
  AppSyncClient(this.client, this.app) {
    session = AppSyncSession(request: _request);
  }
  final GraphQLClient client;
  final String app;
  late final AppSyncSession session;
  bool _unsupported = false;
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
    if (state['status'] == 'unsupported') {
      await refresh();
      return;
    }
    if (state['status'] != 'ready' || state['projection_version'] != 1) {
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
    if (_unsupported) return {'status': 'unsupported'};
    final state = operation == 'state';
    final response = await client.query(
      QueryOptions(
        document: gql(
          state
              ? r'''
      query AppSyncState($app:String!) { appSyncState(app:$app) }
    '''
              : r'''
      query AppSyncSnapshot($app:String!,$revision:String!,$itemIds:[Int!],$collectionIds:[String!]) {
        appSyncSnapshot(app:$app,revision:$revision,itemIds:$itemIds,collectionIds:$collectionIds)
      }
    ''',
        ),
        variables: {'app': app, ...variables},
        fetchPolicy: FetchPolicy.noCache,
        queryRequestTimeout: const Duration(seconds: 30),
      ),
    );
    if (response.hasException) {
      if (response.exception!.graphqlErrors.any(
        (error) => error.message.contains('Cannot query field "appSync'),
      )) {
        _unsupported = true;
        return {'status': 'unsupported'};
      }
      throw response.exception!;
    }
    final raw = response.data?[state ? 'appSyncState' : 'appSyncSnapshot'];
    return Map<String, dynamic>.from(
      (raw is String ? jsonDecode(raw) : raw) as Map,
    );
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
          if (value['metadata']?['kind'] == 'Topic')
            value['metadata']['name'] as String,
      }.toList()..sort()),
    );
  }
}
