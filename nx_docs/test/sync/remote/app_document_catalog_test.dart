import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/sync/remote/app_document_remote_api.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';

void main() {
  test(
    'filtered pages keep loading until the document limit is filled',
    () async {
      final cursors = <String?>[];
      final reads = AppReads(
        MockClient((request) async {
          final cursor = request.url.queryParameters['cursor'];
          cursors.add(cursor);
          Map<String, Object?> row(int id, String type) => {
            'id': id,
            'name': type,
            'model_type': {'id': id, 'name': type},
            'updated_at': '2026-09-25T00:00:00Z',
          };
          return http.Response(
            jsonEncode({
              'items': cursor == null
                  ? [row(1, 'Book'), row(2, 'Book Chapter')]
                  : [row(3, 'Document'), row(4, 'Document')],
              'next_cursor': cursor == null ? 'next-page' : null,
            }),
            200,
          );
        }),
        Uri.parse('https://example.test'),
        'docs',
      );
      addTearDown(reads.close);
      final api = AppDocumentRemoteApi(reads, FakeDocumentRemoteApi());
      final rows = await api.fetchCatalog(const CatalogQuery.recent(limit: 1));
      expect(rows.map((row) => row.id), [3]);
      expect(cursors, [null, 'next-page']);
    },
  );
}
