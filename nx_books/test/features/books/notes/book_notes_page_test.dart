import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/features/books/notes/book_notes_page.dart';
import 'package:nx_documents/nx_documents.dart';

void main() {
  testWidgets('book notes opens the shared native reader for a Book model', (
    tester,
  ) async {
    final repository = _BookNotesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookNotesRepositoryProvider.overrideWithValue(repository),
          bookNotesImageBaseProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: BookNotesPage(bookId: 4195)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Book Notes'), findsOneWidget);
    expect(find.byType(DocumentReader), findsOneWidget);
    expect(
      repository.loaded,
      const DocumentIdentity(id: 4195, modelType: 'Book'),
    );
  });
}

class _BookNotesRepository implements DocumentContentRepository {
  DocumentIdentity? loaded;

  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async {
    loaded = identity;
    return DocumentContent(
      identity: identity,
      title: 'Cold Start Problem',
      plainText: '# Summary\nNetwork effects compound.',
      jsonDocument: const <String, dynamic>{},
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<DocumentContent> save(DocumentContent content) async => content;
}
