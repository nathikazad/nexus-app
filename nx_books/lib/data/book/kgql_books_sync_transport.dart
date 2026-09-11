import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/documents.dart';
import '../offline/books_hash_sync.dart';

final class KgqlBooksSyncTransport implements BooksSyncTransport {
  const KgqlBooksSyncTransport(this.client);
  final GraphQLClient client;
  // Override GraphQL's normal 90-second limit, not just an outer Future timer.
  // The server allows four minutes of SQL work, leaving a minute for transfer.
  static const requestTimeout = Duration(minutes: 5);

  @override
  Future<DocumentSyncResponse> manifest() => syncDocuments(
    client,
    manifest: const [],
    manifestOnly: true,
    requestTimeout: requestTimeout,
  );

  @override
  Future<DocumentSyncResponse> download(Set<int> ids) => syncDocuments(
    client,
    manifest: [
      for (final id in ids) {'id': id, 'hash': null},
    ],
    documentIds: ids,
    requestTimeout: requestTimeout,
  );
}
