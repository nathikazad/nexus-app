import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/documents.dart';
import 'package:nx_db/app_sync.dart';
import '../offline/books_hash_sync.dart';

final class KgqlBooksSyncTransport implements BooksSyncTransport {
  const KgqlBooksSyncTransport(this.client);
  final GraphQLClient client;
  // Override GraphQL's normal 90-second limit, not just an outer Future timer.
  // The server allows four minutes of SQL work, leaving a minute for transfer.
  static const requestTimeout = documentBulkSyncTimeout;

  @override
  Future<DocumentSyncResponse> manifest() => _sync(manifestOnly: true);
  @override
  Future<DocumentSyncResponse> download(Set<int> ids) => _sync(ids: ids);
  Future<DocumentSyncResponse> _sync({
    Set<int>? ids,
    bool manifestOnly = false,
  }) async {
    final response = await AppSyncClient.forOwner(
      this,
      client,
      'books',
    ).documents(localManifest: const [], ids: ids, manifestOnly: manifestOnly);
    if (response == null) throw StateError('Books sync is unavailable');
    return response;
  }
}
