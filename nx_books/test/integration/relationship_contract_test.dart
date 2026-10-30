import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/documents.dart' as documents;
import 'package:nx_db/kgql.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_books/data/book/kgql_book_repository.dart';
import 'package:nx_books/data/book/kgql_reading_history.dart';

void main() {
  test(
    'book chapters, transcripts and sync preserve the endpoint contract',
    () async {
      final endpoint =
          Platform.environment['NX_BOOKS_INTEGRATION_GRAPHQL_HTTP']!;
      final client = createClient(
        endpoint,
        Platform.environment['NX_BOOKS_INTEGRATION_USER_ID'] ?? '1',
        domainId: int.parse(
          Platform.environment['NX_BOOKS_INTEGRATION_DOMAIN_ID']!,
        ),
      );
      final ids = <int>[];
      addTearDown(() async {
        for (final id in ids.reversed) {
          await setKgqlModel(client, setKgqlDelete(id));
        }
      });
      final repo = KgqlBookRepository(client: client);
      final book = await repo.createBook(title: 'Relationship test book');
      ids.add(book.id);
      final other = await repo.createBook(
        title: 'Other relationship test book',
      );
      ids.add(other.id);
      final chapter = await setKgqlModel(
        client,
        SetModelRequest(
          modelType: 'Book Chapter',
          name: 'Relationship test chapter',
          attributes: [SetModelAttribute(key: 'chapter_number', value: 1)],
        ),
      );
      ids.add(chapter);
      Future<void> attach(int bookId) async {
        await setKgqlModel(
          client,
          SetModelRequest(
            id: bookId,
            relations: [
              ModelRelation(
                modelType: 'Book Chapter',
                relationName: 'book_book_chapter',
                link: [chapter],
              ),
            ],
          ),
        );
      }

      await attach(book.id);
      await expectLater(
        attach(other.id),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('at most one'),
          ),
        ),
      );
      final loaded = await fetchKgqlModelById(
        client,
        modelTypeName: 'Book',
        id: book.id,
        struct: {
          'id': true,
          'name': true,
          'Book Chapter': {'id': true, 'name': true},
        },
      );
      expect(loaded!.relations!['Book Chapter']!.map((m) => m.id), [chapter]);
      final transcript = await setKgqlModel(
        client,
        SetModelRequest(
          modelType: 'Transcript',
          name: 'Relationship test conversation',
          attributes: [
            SetModelAttribute(
              key: 'messages',
              value: {
                '1': {'role': 'user', 'content': 'Tell me about this chapter'},
              },
            ),
          ],
        ),
      );
      ids.add(transcript);
      Future<void> attachTranscript(int id) async {
        await setKgqlModel(
          client,
          SetModelRequest(
            id: id,
            relations: [
              ModelRelation(modelType: 'Transcript', link: [transcript]),
            ],
          ),
        );
      }

      await attachTranscript(chapter);
      await expectLater(
        attachTranscript(other.id),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('at most one'),
          ),
        ),
      );
      final history = await fetchReadingHistory(
        client,
        DocumentIdentity(id: chapter, modelType: 'Book Chapter'),
      );
      expect(history.messages.single.text, 'Tell me about this chapter');
      final downloaded = await documents.syncDocuments(
        client,
        manifest: [],
        documentIds: {book.id, chapter},
      );
      final entry = downloaded.documents.singleWhere(
        (e) => e.documentId == chapter,
      );
      expect((entry.document['transcripts'] as List).single['id'], transcript);
      final unchanged = await documents.syncDocuments(
        client,
        manifest: [
          for (final e in downloaded.documents)
            {'id': e.documentId, 'hash': e.syncHash},
        ],
        documentIds: {book.id, chapter},
      );
      expect(unchanged.documents, isEmpty);
    },
    skip: Platform.environment['RUN_NX_BOOKS_INTEGRATION'] != 'true',
    tags: ['integration'],
  );
}
