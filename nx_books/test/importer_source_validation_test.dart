// Batch bridge for the Python importer. No network or database access.
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/epub/book_source.dart';
import 'package:nx_books/epub/epub_source_resolver.dart';

Iterable<Map<String, dynamic>> blocks(Map<String, dynamic> root) sync* {
  for (final child in (root['children'] as List? ?? [])) {
    final block = Map<String, dynamic>.from(child as Map);
    yield block;
    yield* blocks(block);
  }
}

void main() {
  final requestPath = Platform.environment['NX_BOOK_SOURCE_REQUEST'];
  test(
    'generated heading sources round-trip and resolve with the real reader',
    () async {
      final request = jsonDecode(File(requestPath!).readAsStringSync()) as Map;
      final book = await EpubReader.readBook(
        await File(request['epub'] as String).readAsBytes(),
        decodeCover: false,
      );
      var linked = 0;
      final failures = <String>[];
      final documents = request['documents'] as List;
      for (final wrapper in documents) {
        final root = Map<String, dynamic>.from(wrapper['document'] as Map);
        final document = Document.fromJson({'document': root});
        try {
          final restored = Map<String, dynamic>.from(
            document.toJson()['document'] as Map,
          );
          final originalSources = blocks(
            root,
          ).where((b) => b['data']?['book_source'] != null).toList();
          final restoredSources = blocks(
            restored,
          ).where((b) => b['data']?['book_source'] != null).toList();
          expect(restoredSources.length, originalSources.length);
          for (var i = 0; i < restoredSources.length; i++) {
            final block = restoredSources[i];
            expect(block['type'], 'heading');
            expect(
              block['data']['book_source'],
              originalSources[i]['data']['book_source'],
            );
            final source = BookSource.fromJson(block['data']['book_source']);
            expect(source, isNotNull);
            try {
              resolveEpubSource(book, source!);
            } catch (error) {
              failures.add(
                'Heading ${block['data']['delta']}: ${source?.resource}: $error',
              );
            }
            linked++;
          }
        } finally {
          document.dispose();
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
      File(Platform.environment['NX_BOOK_SOURCE_REPORT']!).writeAsStringSync(
        jsonEncode({'documents': documents.length, 'linked': linked}),
      );
    },
    skip: requestPath == null,
  );
}
